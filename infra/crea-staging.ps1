# Crea l'ambiente di STAGING su Azure e lo collega a GitHub.
# Copia la configurazione di prod (rg-scacchiasd) con nomi "-staging".
#
# Eseguito una volta il 13/11/2026. Lo script e' qui come documentazione di cosa
# esiste su Azure e per poterlo rifare: se una risorsa esiste gia', il comando
# relativo fallisce e lo script si ferma.
#
# Requisiti: Azure CLI (az login --tenant <tenant>), GitHub CLI (gh auth login), sqlcmd.
# Uso: powershell -ExecutionPolicy Bypass -File .\infra\crea-staging.ps1

$ErrorActionPreference = 'Stop'

$tenant       = '097669d4-adc4-4fc1-bb61-8a2ea6fd85e5'
$gruppo       = 'rg-scacchiasd'
$area         = 'italynorth'
$piano        = 'plan-scacchiasd'                  # stesso piano gratuito F1 di prod
$app          = 'scacchiasd-staging'
$serverSql    = 'scacchiasd-sql-staging'
$database     = 'ScacchiASD'
$identitaGh   = 'id-scacchiasd-github-staging'     # chiave che GitHub usa per pubblicare SOLO su staging
$adminSql     = 'teoaye2001@gmail.com'
$ipCasa       = '93.51.99.163'
$repo         = 'MatteoAiello2001/ScacchiASD'
$soggettoGh   = 'repo:MatteoAiello2001@81436853/ScacchiASD@1434957523:environment:staging'
$workspace    = '/subscriptions/036c10ea-6544-4fbf-b885-50e9551c2463/resourceGroups/DefaultResourceGroup-ITN/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-036c10ea-6544-4fbf-b885-50e9551c2463-ITN'

# Lancia un comando esterno e si ferma se fallisce.
function Esegui {
  $comando = $args[0]
  $argomenti = $args[1..($args.Length - 1)]
  & $comando @argomenti
  if ($LASTEXITCODE -ne 0) { throw "Comando fallito: $comando $argomenti" }
}

# Scrive un oggetto in un file JSON temporaneo e ne restituisce il percorso (per az ... @file).
function FileJson($oggetto) {
  $file = [System.IO.Path]::GetTempFileName()
  $oggetto | ConvertTo-Json -Depth 10 | Set-Content -Path $file -Encoding ascii
  return $file
}

function Passo($testo) { Write-Host "`n== $testo" -ForegroundColor Cyan }

# ---------------------------------------------------------------- Application Insights
Passo 'Application Insights scacchiasd-staging (con tetto di 100 MB al giorno)'
$aiFile = FileJson @{
  location   = $area
  kind       = 'web'
  properties = @{
    Application_Type    = 'web'
    WorkspaceResourceId = $workspace
    IngestionMode       = 'LogAnalytics'
    RetentionInDays     = 90
  }
}
$aiId = (Esegui az resource create -g $gruppo -n $app --resource-type microsoft.insights/components --is-full-object --properties "@$aiFile" --query id -o tsv)
$aiConn = (Esegui az resource show --ids $aiId --query properties.ConnectionString -o tsv)
$capFile = FileJson @{
  CurrentBillingFeatures = @('Basic')
  DataVolumeCap          = @{ Cap = 0.1; StopSendNotificationWhenHitCap = $false; WarningThreshold = 90 }
}
Esegui az rest --method put --url "https://management.azure.com$aiId/currentbillingfeatures?api-version=2015-05-01" --body "@$capFile" -o none

# ---------------------------------------------------------------- App web
Passo 'App web scacchiasd-staging (stesso piano F1 di prod)'
Esegui az webapp create -g $gruppo -p $piano -n $app --runtime 'DOTNETCORE:10.0' --https-only true --assign-identity '[system]' --domain-name-scope TenantReuse --basic-auth Disabled -o none
Esegui az webapp config set -g $gruppo -n $app --ftps-state FtpsOnly --min-tls-version 1.2 --http20-enabled false -o none
$impostazioni = FileJson @{
  ASPNETCORE_ENVIRONMENT                     = 'Staging'
  APPLICATIONINSIGHTS_CONNECTION_STRING      = $aiConn
  ApplicationInsightsAgent_EXTENSION_VERSION = '~3'
  XDT_MicrosoftApplicationInsights_Mode      = 'Recommended'
}
Esegui az webapp config appsettings set -g $gruppo -n $app --settings "@$impostazioni" -o none
$appId = (Esegui az webapp show -g $gruppo -n $app --query id -o tsv)
$indirizzo = (Esegui az webapp show -g $gruppo -n $app --query defaultHostName -o tsv)

# ---------------------------------------------------------------- SQL
Passo 'Server SQL scacchiasd-sql-staging (solo login Microsoft Entra)'
$adminSid = (Esegui az ad signed-in-user show --query id -o tsv)
Esegui az sql server create -g $gruppo -n $serverSql -l $area --enable-ad-only-auth --external-admin-principal-type User --external-admin-name $adminSql --external-admin-sid $adminSid --minimal-tls-version 1.2 -o none
Esegui az sql server firewall-rule create -g $gruppo -s $serverSql -n AllowAllWindowsAzureIps --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 -o none
Esegui az sql server firewall-rule create -g $gruppo -s $serverSql -n CasaAiello --start-ip-address $ipCasa --end-ip-address $ipCasa -o none

Passo 'Database ScacchiASD (offerta gratuita, pausa a fine quota)'
Esegui az sql db create -g $gruppo -s $serverSql -n $database --edition GeneralPurpose --compute-model Serverless --family Gen5 --capacity 2 --min-capacity 0.5 --max-size 32GB --zone-redundant false --backup-storage-redundancy Local --use-free-limit true --free-limit-exhaustion-behavior AutoPause -o none

Passo "Utente [$app] nel database (identita' dell'app, permessi minimi)"
$sql = "CREATE USER [$app] FROM EXTERNAL PROVIDER; ALTER ROLE db_datareader ADD MEMBER [$app]; ALTER ROLE db_datawriter ADD MEMBER [$app]; ALTER ROLE db_ddladmin ADD MEMBER [$app];"
Esegui sqlcmd -S "tcp:$serverSql.database.windows.net,1433" -d $database --authentication-method ActiveDirectoryDefault -Q $sql

# ---------------------------------------------------------------- Identita' per GitHub
Passo "Identita' $identitaGh (puo' pubblicare solo su staging)"
Esegui az identity create -g $gruppo -n $identitaGh -l $area -o none
$clientId = (Esegui az identity show -g $gruppo -n $identitaGh --query clientId -o tsv)
$principalId = (Esegui az identity show -g $gruppo -n $identitaGh --query principalId -o tsv)
Esegui az identity federated-credential create -g $gruppo --identity-name $identitaGh -n github-staging --issuer https://token.actions.githubusercontent.com --subject $soggettoGh --audiences api://AzureADTokenExchange -o none
Esegui az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --role 'Website Contributor' --scope $appId -o none

# ---------------------------------------------------------------- GitHub
Passo 'GitHub: environment staging (solo da main) con le sue variabili'
Esegui gh api -X PUT "repos/$repo/environments/staging" -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true' --silent
Esegui gh api -X POST "repos/$repo/environments/staging/deployment-branch-policies" -f name=main -f type=branch --silent
Esegui gh variable set AZURE_CLIENT_ID --env staging --body $clientId -R $repo
Esegui gh variable set AZURE_TENANT_ID --env staging --body $tenant -R $repo
Esegui gh variable set AZURE_SUBSCRIPTION_ID --env staging --body (az account show --query id -o tsv) -R $repo

Passo 'GitHub: production richiede la mia approvazione'
$mioId = (Esegui gh api user --jq .id)
Esegui gh api -X PUT "repos/$repo/environments/production" -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true' -F 'reviewers[][type]=User' -F "reviewers[][id]=$mioId" --silent

Passo 'Fatto'
Write-Host "Staging: https://$indirizzo" -ForegroundColor Green
