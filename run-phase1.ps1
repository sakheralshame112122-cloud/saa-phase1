# أمر واحد: بناء + إقلاع + إثبات (Windows)
$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot
$DC = "docker compose --env-file .env -f infra/docker-compose.yml"
Write-Host "== بناء وإقلاع (أول مرة 5–12 دقيقة) ==" -ForegroundColor Cyan
Invoke-Expression "$DC --profile web up -d --build"
if ($LASTEXITCODE -ne 0) { Write-Host "فشل الإقلاع — أرسل لي الناتج أعلاه" -ForegroundColor Red; exit 1 }
Start-Sleep -Seconds 25
powershell -ExecutionPolicy Bypass -File .\collect-proof.ps1
