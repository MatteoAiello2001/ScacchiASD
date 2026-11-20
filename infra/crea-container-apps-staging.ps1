# Crea la PROVA di staging su Azure Container Apps, accanto allo staging su App Service.
# Usa lo stesso database di staging (scacchiasd-sql-staging) e la stessa identita' di rilascio
# di staging (id-scacchiasd-github-staging).
#
# Eseguito una volta il 20/11/2026. Come crea-staging.ps1, serve da documentazione e per poterlo
# rifare: se una risorsa esiste gia', il comando relativo fallisce e lo script si ferma.
#
# Requisiti: Azure CLI (az login --tenant <tenant>) con l'estensione containerapp, sqlcmd.
# Uso: powershell -ExecutionPolicy Bypass -File .\infra\crea-container-apps-staging.ps1

$ErrorActionPreference = 'Stop'

$gruppo       = 'rg-scacchiasd'
$area         = 'italynorth'
$ambienteCa   = 'cae-scacchiasd'                   # l'ambiente Container Apps (il "porto")
$app          = 'scacchiasd-staging'               # Container App (tipo diverso dall'App Service omonimo)
$job          = 'scacchiasd-staging-migra'         # lavoro che applica le migration a ogni rilascio
$appInsights  = 'scacchiasd-staging'               # Application Insights di staging, gia' esistente
$serverSql    = 'scacchiasd-sql-staging'
$database     = 'ScacchiASD'
$identitaGh   = 'id-scacchiasd-github-staging'
$wsGruppo     = 'DefaultResourceGroup-ITN'
$wsNome       = 'DefaultWorkspace-036c10ea-6544-4fbf-b885-50e9551c2463-ITN'
# Immagine segnaposto: serve solo a creare le risorse; il primo rilascio la sostituisce con la nostra.
$segnaposto   = 'mcr.microsoft.com/dotnet/samples:aspnetapp'

function Esegui {
  $comando = $args[0]
  $argomenti = $args[1..($args.Length - 1)]
  & $comando @argomenti
  if ($LASTEXITCODE -ne 0) { throw "Comando fallito: $comando $argomenti" }
}

function Passo($testo) { Write-Host "`n== $testo" -ForegroundColor Cyan }

Passo 'Servizio Container Apps attivo sull''abbonamento'
Esegui az extension add --name containerapp --upgrade --only-show-errors
Esegui az provider register --namespace Microsoft.App --wait

Passo "Ambiente $ambienteCa (a consumo, log nello spazio di lavoro che usa gia' Application Insights)"
$wsId = (Esegui az monitor log-analytics workspace show -g $wsGruppo -n $wsNome --query customerId -o tsv)
$wsChiave = (Esegui az monitor log-analytics workspace get-shared-keys -g $wsGruppo -n $wsNome --query primarySharedKey -o tsv)
Esegui az containerapp env create -g $gruppo -n $ambienteCa -l $area --logs-destination log-analytics --logs-workspace-id $wsId --logs-workspace-key $wsChiave -o none

$aiConn = (Esegui az resource show -g $gruppo -n $appInsights --resource-type microsoft.insights/components --query properties.ConnectionString -o tsv)

Passo "Container App $app (si spegne quando non la usa nessuno: da 0 a 1 copia)"
Esegui az containerapp create -g $gruppo -n $app --environment $ambienteCa --image $segnaposto `
  --ingress external --target-port 8080 --min-replicas 0 --max-replicas 1 --cpu 0.5 --memory 1.0Gi `
  --system-assigned `
  --env-vars ASPNETCORE_ENVIRONMENT=Staging Database__MigraAllAvvio=false "APPLICATIONINSIGHTS_CONNECTION_STRING=$aiConn" -o none

Passo "Lavoro $job (applica le migration, poi si spegne)"
Esegui az containerapp job create -g $gruppo -n $job --environment $ambienteCa --image $segnaposto `
  --trigger-type Manual --replica-timeout 600 --replica-retry-limit 0 --parallelism 1 --replica-completion-count 1 `
  --cpu 0.5 --memory 1.0Gi --system-assigned `
  '--args=--migra' `
  --env-vars ASPNETCORE_ENVIRONMENT=Staging "APPLICATIONINSIGHTS_CONNECTION_STRING=$aiConn" -o none

Passo 'Utenti nel database di staging'
# L'identita' dell'app ha lo stesso nome dello staging su App Service ("scacchiasd-staging"):
# la registro con il suo ID e un nome che, come vuole Azure, inizia con quello originale.
# L'app legge e scrive soltanto; le tabelle le cambia solo il lavoro delle migration.
$appOid = (Esegui az containerapp show -g $gruppo -n $app --query identity.principalId -o tsv)
$sql = @"
CREATE USER [$app-ca] FROM EXTERNAL PROVIDER WITH OBJECT_ID = '$appOid';
ALTER ROLE db_datareader ADD MEMBER [$app-ca];
ALTER ROLE db_datawriter ADD MEMBER [$app-ca];
CREATE USER [$job] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [$job];
ALTER ROLE db_datawriter ADD MEMBER [$job];
ALTER ROLE db_ddladmin ADD MEMBER [$job];
"@
# -b: si ferma (e fa fallire lo script) se un comando SQL da' errore.
Esegui sqlcmd -b -S "tcp:$serverSql.database.windows.net,1433" -d $database --authentication-method ActiveDirectoryDefault -Q $sql

Passo "Permessi per la chiave di rilascio $identitaGh (solo su ambiente, app e lavoro di staging)"
$ghOid = (Esegui az identity show -g $gruppo -n $identitaGh --query principalId -o tsv)
foreach ($scope in @(
  (az containerapp env show -g $gruppo -n $ambienteCa --query id -o tsv),
  (az containerapp show -g $gruppo -n $app --query id -o tsv),
  (az containerapp job show -g $gruppo -n $job --query id -o tsv)
)) {
  Esegui az role assignment create --assignee-object-id $ghOid --assignee-principal-type ServicePrincipal --role Contributor --scope $scope -o none
}

Passo 'Fatto'
$indirizzo = (Esegui az containerapp show -g $gruppo -n $app --query properties.configuration.ingress.fqdn -o tsv)
Write-Host "Staging su Container Apps: https://$indirizzo" -ForegroundColor Green
