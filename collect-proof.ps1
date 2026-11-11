# جمع إثبات PHASE 1 — PowerShell (Windows)
# الاستخدام: الزر الأيمن على الملف ← Run with PowerShell
#            أو:  powershell -ExecutionPolicy Bypass -File .\collect-proof.ps1
$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot
$out = Join-Path $PSScriptRoot "PHASE1_PROOF.txt"
"" | Set-Content $out -Encoding UTF8

function Say($t) { $t | Tee-Object -FilePath $out -Append | Out-Null; Write-Host $t }
function Run($cmd) {
  Say "`$ $cmd"
  $r = Invoke-Expression $cmd 2>&1 | Out-String
  $r | Tee-Object -FilePath $out -Append | Out-Null
  Say ""
}

Say "===== PHASE 1 PROOF · $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) (UTC) ====="
$DC = "docker compose --env-file .env -f infra/docker-compose.yml"
Run "docker version --format '{{.Server.Version}}'"
Run "$DC config --services"
Run "$DC ps"
Start-Sleep -Seconds 20
Run "$DC ps"
Say "----- health endpoints -----"
Run "curl.exe -k -s -w '`nHTTP %{http_code}`n' https://localhost/health"
Run "curl.exe -k -s -w '`nHTTP %{http_code}`n' https://localhost/health/ready"
Run "curl.exe -k -s -w '`nHTTP %{http_code}`n' https://localhost/api/v1/health"
Run "curl.exe -k -s -o NUL -w 'HTTP %{http_code} -> %{redirect_url}`n' https://localhost/"
Run "curl.exe -k -s -o NUL -w 'HTTP %{http_code}`n' https://localhost/status"
Say "----- uptime يزيد؟ -----"
Run "curl.exe -k -s https://localhost/health; Start-Sleep -Seconds 3; curl.exe -k -s https://localhost/health"
Say "----- من داخل حاوية api -----"
Run "$DC exec -T api python -c `"import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000/health/ready',timeout=5).read().decode())`""
Say "----- السجلات -----"
Run "$DC logs --tail=25 api"
Run "$DC logs --tail=15 web"
Run "$DC logs --tail=15 nginx"
Say "===== انتهى · أرسل ملف PHASE1_PROOF.txt كما هو ====="
Write-Host "`nتم إنشاء: $out" -ForegroundColor Green
