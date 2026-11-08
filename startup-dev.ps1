# Avvia l'ambiente di DEV: backend e frontend, ciascuno in una propria finestra
# PowerShell. Per fermarli: Ctrl+C nella rispettiva finestra (o chiuderla).
# Il frontend parte solo quando il backend risponde, poi si apre il browser
# su http://localhost:4201.
#
# Uso (da PowerShell, nella radice del progetto):
#   powershell -ExecutionPolicy Bypass -File .\startup-dev.ps1
#
# Non serve essere amministratori.

$ErrorActionPreference = 'Stop'

$backend  = Join-Path $PSScriptRoot 'backend'
$frontend = Join-Path $PSScriptRoot 'frontend'
$portaBackend = 7244

# True appena la porta accetta connessioni, false se non succede entro $secondi.
function Attendi-Porta([int]$porta, [int]$secondi) {
  $scadenza = (Get-Date).AddSeconds($secondi)
  while ((Get-Date) -lt $scadenza) {
    $client = New-Object System.Net.Sockets.TcpClient
    try { $client.Connect('localhost', $porta); return $true }
    catch { Start-Sleep -Seconds 1 }
    finally { $client.Dispose() }
  }
  return $false
}

Write-Host "Avvio backend (https://localhost:$portaBackend)..." -ForegroundColor Cyan
Start-Process powershell -WorkingDirectory $backend -ArgumentList @(
  '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command',
  "`$Host.UI.RawUI.WindowTitle = 'ScacchiASD DEV - backend'; dotnet run --project ScacchiASD.Api --launch-profile Development"
)

# La prima compilazione puo' essere lenta: aspetto fino a 3 minuti.
Write-Host 'Aspetto che il backend sia pronto...' -ForegroundColor Cyan
if (-not (Attendi-Porta $portaBackend 180)) {
  Write-Host 'Il backend non risponde: guarda la finestra "ScacchiASD DEV - backend". Il frontend non viene avviato.' -ForegroundColor Red
  exit 1
}
Write-Host 'Backend pronto.' -ForegroundColor Green

if (-not (Test-Path (Join-Path $frontend 'node_modules'))) {
  Write-Host 'Prima volta: installo le dipendenze del frontend...' -ForegroundColor Cyan
  Push-Location $frontend
  try {
    npm install
    if ($LASTEXITCODE -ne 0) { throw 'npm install fallito' }
  }
  finally { Pop-Location }
}

Write-Host 'Avvio frontend (http://localhost:4201)...' -ForegroundColor Cyan
Start-Process powershell -WorkingDirectory $frontend -ArgumentList @(
  '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command',
  "`$Host.UI.RawUI.WindowTitle = 'ScacchiASD DEV - frontend'; npm start"
)

Write-Host 'Aspetto che il frontend sia pronto...' -ForegroundColor Cyan
$pronto = $false
foreach ($i in 1..60) {
  Start-Sleep -Seconds 2
  try { Invoke-WebRequest 'http://localhost:4201' -UseBasicParsing -TimeoutSec 3 | Out-Null; $pronto = $true; break } catch { }
}

if ($pronto) {
  Start-Process 'http://localhost:4201'
  Write-Host 'Pronto: http://localhost:4201' -ForegroundColor Green
}
else {
  Write-Host 'Il frontend non risponde ancora: guarda la finestra "ScacchiASD DEV - frontend".' -ForegroundColor Red
}
