# Crea la "sveglia" delle app: una Logic App di Azure che ogni 10 minuti chiama /api/info
# di produzione e di staging, cosi' le app del piano gratuito F1 non si spengono
# (spente, la prima pagina ci mette circa 2 minuti).
#
# /api/info NON usa il database: il database continua ad andare in pausa e non consuma le ore gratuite.
# Costo: Logic App a consumo, circa 13.000 operazioni al mese, le prime 4.000 gratis: circa 0,20 euro al mese.
#
# Eseguito il 23/11/2026 (sostituisce il workflow GitHub "Sveglia", i cui orari GitHub non rispettava).
# Requisiti: Azure CLI (az login --tenant <tenant>).
# Uso: powershell -ExecutionPolicy Bypass -File .\infra\crea-sveglia.ps1

$ErrorActionPreference = 'Stop'

$gruppo = 'rg-scacchiasd'
$area   = 'italynorth'
$nome   = 'la-scacchiasd-sveglia'
$prod    = 'https://scacchiasd-c7gxdch7amgsb4cf.italynorth-01.azurewebsites.net/api/info'
$staging = 'https://scacchiasd-staging-ffh9gyhjgsdcbcgd.italynorth-01.azurewebsites.net/api/info'

function Esegui {
  $comando = $args[0]
  $argomenti = $args[1..($args.Length - 1)]
  & $comando @argomenti
  if ($LASTEXITCODE -ne 0) { throw "Comando fallito: $comando $argomenti" }
}

# Una chiamata GET senza nuovi tentativi: se una volta non risponde, ci riprova il giro dopo.
function Chiamata($indirizzo) {
  return @{
    type   = 'Http'
    inputs = @{ method = 'GET'; uri = $indirizzo; retryPolicy = @{ type = 'none' } }
    limit  = @{ timeout = 'PT3M' }
    runAfter = @{}
  }
}

Write-Host "`n== Servizio Logic Apps attivo sull'abbonamento" -ForegroundColor Cyan
Esegui az provider register --namespace Microsoft.Logic --wait

Write-Host "`n== Logic App $nome (ogni 10 minuti: produzione e staging, in parallelo)" -ForegroundColor Cyan
$risorsa = @{
  location   = $area
  properties = @{
    state      = 'Enabled'
    definition = @{
      '$schema'      = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion = '1.0.0.0'
      triggers       = @{
        Ogni_10_minuti = @{ type = 'Recurrence'; recurrence = @{ frequency = 'Minute'; interval = 10 } }
      }
      actions        = @{
        Produzione = (Chiamata $prod)
        Staging    = (Chiamata $staging)
      }
      outputs        = @{}
    }
  }
}
$file = [System.IO.Path]::GetTempFileName()
$risorsa | ConvertTo-Json -Depth 20 | Set-Content -Path $file -Encoding ascii
Esegui az resource create -g $gruppo -n $nome --resource-type Microsoft.Logic/workflows --is-full-object --properties "@$file" -o none
Remove-Item $file

Write-Host "`n== Fatto: cronologia nel portale Azure, Logic App $nome > Cronologia esecuzioni" -ForegroundColor Green
