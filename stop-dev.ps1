# Ferma l'ambiente di DEV (backend e frontend avviati con startup-dev.ps1,
# oppure da Visual Studio / npm start) e chiude le loro finestre.
#
# Uso (da PowerShell, nella radice del progetto):
#   powershell -ExecutionPolicy Bypass -File .\stop-dev.ps1

$ErrorActionPreference = 'Stop'

# Porte del dev: backend 7244 (https) e 5019 (http), frontend 4201.
$porte = 7244, 5019, 4201
$titoloFinestre = 'ScacchiASD DEV'

# Termina un processo con tutti i suoi figli. Gli errori di taskkill sono ignorati
# (capita che un figlio sia gia' chiuso o non terminabile, ad esempio conhost).
function Termina-Albero([int]$id) {
  cmd /c "taskkill /PID $id /T /F >nul 2>&1"
}

function Processi-InAscolto {
  # Una porta alla volta: interrogarle tutte insieme non e' affidabile.
  foreach ($porta in $porte) {
    Get-NetTCPConnection -State Listen -LocalPort $porta -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty OwningProcess
  }
}

$fermati = 0

# 1. Le finestre aperte da startup-dev.ps1 (con dentro backend e frontend).
$finestre = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -like "*$titoloFinestre*" }
foreach ($f in $finestre) {
  Write-Host "Chiudo la finestra $titoloFinestre (PID $($f.ProcessId))..." -ForegroundColor Cyan
  Termina-Albero $f.ProcessId
  $fermati++
}

# 2. Quello che resta sulle porte del dev (es. avviato da Visual Studio o con npm start a mano).
foreach ($id in @(Processi-InAscolto | Select-Object -Unique)) {
  if ($id -eq 0) { continue }
  $nome = (Get-Process -Id $id -ErrorAction SilentlyContinue).ProcessName
  Write-Host "Fermo $nome (PID $id)..." -ForegroundColor Cyan
  Termina-Albero $id
  $fermati++
}

if ($fermati -eq 0) {
  Write-Host "Il dev non e' acceso (nessuno ascolta sulle porte $($porte -join ', '))." -ForegroundColor Yellow
  exit
}

# 3. Verifica: le porte devono essere libere.
Start-Sleep -Seconds 1
$rimasti = @(Processi-InAscolto | Where-Object { $_ -ne 0 } | Select-Object -Unique)
if ($rimasti.Count -gt 0) {
  Write-Host "ATTENZIONE: qualcosa ascolta ancora sulle porte del dev (PID $($rimasti -join ', '))." -ForegroundColor Red
  exit 1
}

Write-Host "Dev fermato." -ForegroundColor Green
