# جمع إثبات PHASE 1 — Git Bash / WSL
# الاستخدام:  bash collect-proof.sh
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
DC="docker compose --env-file .env -f infra/docker-compose.yml"
OUT="PHASE1_PROOF.txt"
: > "$OUT"

say(){ echo "$*" | tee -a "$OUT"; }
run(){ echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }

say "===== PHASE 1 PROOF · $(date -u +%Y-%m-%dT%H:%M:%SZ) (UTC) ====="
run "docker version --format '{{.Server.Version}}'"
run "$DC config --services"
run "$DC ps"
sleep 20
run "$DC ps"
say "----- health endpoints (من المضيف عبر nginx) -----"
run "curl -k -s -w '\\nHTTP %{http_code}\\n' https://localhost/health"
run "curl -k -s -w '\\nHTTP %{http_code}\\n' https://localhost/health/ready"
run "curl -k -s -w '\\nHTTP %{http_code}\\n' https://localhost/api/v1/health"
run "curl -k -s -o /dev/null -w 'HTTP %{http_code} -> %{redirect_url}\\n' https://localhost/"
run "curl -k -s -o /dev/null -w 'HTTP %{http_code}\\n' https://localhost/status"
say "----- uptime يزيد؟ (نداءان بفارق 3 ثوانٍ) -----"
run "curl -k -s https://localhost/health; sleep 3; curl -k -s https://localhost/health"
say "----- من داخل حاوية api مباشرة -----"
run "$DC exec -T api python -c \"import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000/health/ready',timeout=5).read().decode())\""
say "----- آخر السجلات -----"
run "$DC logs --tail=25 api"
run "$DC logs --tail=15 web"
run "$DC logs --tail=15 nginx"
say "===== انتهى · أرسل ملف $OUT كما هو ====="
echo "تم إنشاء: $(pwd)/$OUT"
