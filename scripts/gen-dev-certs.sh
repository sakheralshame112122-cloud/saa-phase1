#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CERT_DIR="$ROOT/infra/nginx/certs"
CRT="$CERT_DIR/fullchain.pem"
KEY="$CERT_DIR/privkey.pem"
DAYS="${CERT_DAYS:-825}"
CN="${CERT_CN:-localhost}"

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [[ "$FORCE" -eq 0 && -f "$CRT" && -f "$KEY" ]]; then
  echo "certs already present: $CRT , $KEY"
  openssl x509 -in "$CRT" -noout -subject -dates
  exit 0
fi

command -v openssl >/dev/null 2>&1 || { echo "openssl not found" >&2; exit 2; }

mkdir -p "$CERT_DIR"
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days "$DAYS" \
  -subj "/CN=$CN" \
  -addext "subjectAltName=DNS:$CN,DNS:localhost,IP:127.0.0.1" \
  -keyout "$KEY" -out "$CRT"
chmod 600 "$KEY"
chmod 644 "$CRT"

echo "generated: $CRT"
echo "generated: $KEY"
openssl x509 -in "$CRT" -noout -subject -dates -fingerprint -sha256
