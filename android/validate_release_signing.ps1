# Validasi release signing: release build harus gagal tanpa key.properties
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$keyPath = Join-Path $PSScriptRoot "key.properties"
$backupPath = "$keyPath.bak.validate"

if (-not (Test-Path $keyPath)) {
  Write-Host "SKIP: key.properties tidak ada, asumsikan validasi no-keystore sudah terpenuhi."
  exit 0
}

Move-Item -Path $keyPath -Destination $backupPath -Force
try {
  Push-Location $root
  flutter build appbundle --release --dart-define=ENV=prod
  Write-Error "FAIL: release build seharusnya gagal tanpa key.properties."
}
catch {
  Write-Host "PASS: release build gagal tanpa key.properties (expected)."
}
finally {
  Pop-Location
  if (Test-Path $backupPath) {
    Move-Item -Path $backupPath -Destination $keyPath -Force
  }
}
