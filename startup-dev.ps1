# Avvia l'ambiente di DEV: backend e frontend, ciascuno in una propria finestra
# PowerShell. Per fermarli: Ctrl+C nella rispettiva finestra (o chiuderla).
# Poi apre il browser su http://localhost:4200.
#
# Uso (da PowerShell, nella radice del progetto):
#   powershell -ExecutionPolicy Bypass -File .\startup-dev.ps1
#
# Non serve essere amministratori.

$ErrorActionPreference = 'Stop'

$backend  = Join-Path $PSScriptRoot 'backend'
$frontend = Join-Path $PSScriptRoot 'frontend'

Write-Host 'Avvio backend (https://localhost:7244)...' -ForegroundColor Cyan
Start-Process powershell -WorkingDirectory $backend -ArgumentList @(
  '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command',
  "`$Host.UI.RawUI.WindowTitle = 'ScacchiASD DEV - backend'; dotnet run --project ScacchiASD.Api --launch-profile Development"
)

if (-not (Test-Path (Join-Path $frontend 'node_modules'))) {
  Write-Host 'Prima volta: installo le dipendenze del frontend...' -ForegroundColor Cyan
  Push-Location $frontend
  try {
    npm install
    if ($LASTEXITCODE -ne 0) { throw 'npm install fallito' }
  }
  finally { Pop-Location }
}

Write-Host 'Avvio frontend (http://localhost:4200)...' -ForegroundColor Cyan
Start-Process powershell -WorkingDirectory $frontend -ArgumentList @(
  '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command',
  "`$Host.UI.RawUI.WindowTitle = 'ScacchiASD DEV - frontend'; npm start"
)

Write-Host 'Aspetto che il frontend sia pronto...' -ForegroundColor Cyan
$pronto = $false
foreach ($i in 1..60) {
  Start-Sleep -Seconds 2
  try { Invoke-WebRequest 'http://localhost:4200' -UseBasicParsing -TimeoutSec 3 | Out-Null; $pronto = $true; break } catch { }
}

if ($pronto) {
  Start-Process 'http://localhost:4200'
  Write-Host 'Pronto: http://localhost:4200' -ForegroundColor Green
}
else {
  Write-Host 'Il frontend non risponde ancora: guarda la finestra "ScacchiASD DEV - frontend".' -ForegroundColor Red
}
