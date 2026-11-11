#!/usr/bin/env bash
# أمر واحد: بناء + إقلاع + إثبات
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
DC="docker compose --env-file .env -f infra/docker-compose.yml"
echo "== بناء وإقلاع (أول مرة 5–12 دقيقة) =="
$DC --profile web up -d --build || { echo "فشل الإقلاع — أرسل لي الناتج أعلاه"; exit 1; }
echo "== انتظار الصحة =="
sleep 25
bash ./collect-proof.sh
