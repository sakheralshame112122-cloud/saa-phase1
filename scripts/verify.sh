#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BACKEND="$ROOT/backend"

MYSQL_BIN="${MYSQL_BIN:-mysql}"
ALEMBIC_BIN="${ALEMBIC_BIN:-alembic}"
DB="${VERIFY_DB:-saa_verify}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
MYSQL_SOCKET="${MYSQL_SOCKET:-}"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"

PASS=0
FAIL=0
RESULTS=()

conn_args=(-u "$MYSQL_USER" --default-character-set=utf8mb4)
if [[ -n "$MYSQL_SOCKET" ]]; then
  conn_args+=(--socket="$MYSQL_SOCKET")
else
  conn_args+=(-h "$MYSQL_HOST" -P "$MYSQL_PORT")
fi
if [[ -n "$MYSQL_PASSWORD" ]]; then
  conn_args+=("-p$MYSQL_PASSWORD")
fi

q() {
  "$MYSQL_BIN" "${conn_args[@]}" -N -B -e "$1" 2>/dev/null
}

qd() {
  "$MYSQL_BIN" "${conn_args[@]}" -N -B "$DB" -e "$1" 2>/dev/null
}

sqlrun() {
  "$MYSQL_BIN" "${conn_args[@]}" -N -B "$DB" -e "$1" 2>&1
}

record() {
  local name="$1" expected="$2" actual="$3" ok="$4"
  if [[ "$ok" == "1" ]]; then
    PASS=$((PASS+1))
    RESULTS+=("PASS | $name | متوقع=$expected | فعلي=$actual")
  else
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL | $name | متوقع=$expected | فعلي=$actual")
  fi
}

echo "== SAA Core PHASE 1 verify =="
echo "mysql client : $MYSQL_BIN"
echo "alembic      : $ALEMBIC_BIN"
echo "target db    : $DB"
if [[ -n "$MYSQL_SOCKET" ]]; then echo "transport    : unix socket $MYSQL_SOCKET"; else echo "transport    : tcp $MYSQL_HOST:$MYSQL_PORT"; fi

server_version="$(q 'SELECT VERSION()')"
if [[ -z "$server_version" ]]; then
  echo "FATAL: cannot reach MySQL with the given credentials/transport."
  exit 2
fi
echo "server       : $server_version"
echo

q "DROP DATABASE IF EXISTS \`$DB\`" >/dev/null
q "CREATE DATABASE \`$DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci" >/dev/null

echo "-- alembic upgrade head --"
ALEMBIC_OUT="$(
  cd "$BACKEND" && \
  MYSQL_HOST="$MYSQL_HOST" MYSQL_PORT="$MYSQL_PORT" MYSQL_DATABASE="$DB" \
  MYSQL_USER="$MYSQL_USER" MYSQL_PASSWORD="$MYSQL_PASSWORD" MYSQL_SOCKET="$MYSQL_SOCKET" \
  "$ALEMBIC_BIN" upgrade head 2>&1
)"
ALEMBIC_RC=$?
echo "$ALEMBIC_OUT"
echo "alembic rc=$ALEMBIC_RC"
echo
record "T-00 alembic upgrade head (baseline = D2b §3.2 verbatim)" "rc=0" "rc=$ALEMBIC_RC" "$([[ $ALEMBIC_RC -eq 0 ]] && echo 1 || echo 0)"

table_count="$(qd "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB' AND table_name <> 'alembic_version'")"
record "T-01 عدد الجداول" "31" "$table_count" "$([[ "$table_count" == "31" ]] && echo 1 || echo 0)"

column_count="$(qd "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$DB' AND table_name <> 'alembic_version'")"
record "T-02 عدد الأعمدة" "368" "$column_count" "$([[ "$column_count" == "368" ]] && echo 1 || echo 0)"

fk_count="$(qd "SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema='$DB'")"
record "T-03 عدد المفاتيح الأجنبية" "40" "$fk_count" "$([[ "$fk_count" == "40" ]] && echo 1 || echo 0)"

fk_cascade="$(qd "SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema='$DB' AND delete_rule='CASCADE'")"
fk_restrict="$(qd "SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema='$DB' AND delete_rule='RESTRICT'")"
fk_ws="$(qd "SELECT COUNT(*) FROM information_schema.key_column_usage WHERE table_schema='$DB' AND column_name='workspace_id' AND referenced_table_name IS NOT NULL")"
record "T-04 توزيع سياسة الحذف + FK على workspace_id" "CASCADE=37 · RESTRICT=3 · المجموع=40 · workspace_id=27" "CASCADE=$fk_cascade · RESTRICT=$fk_restrict · المجموع=$((fk_cascade+fk_restrict)) · workspace_id=$fk_ws" \
  "$([[ "$fk_cascade" == "37" && "$fk_restrict" == "3" && "$fk_ws" == "27" ]] && echo 1 || echo 0)"

check_count="$(qd "SELECT COUNT(*) FROM information_schema.check_constraints WHERE constraint_schema='$DB'")"
record "T-05 عدد قيود CHECK" "5" "$check_count" "$([[ "$check_count" == "5" ]] && echo 1 || echo 0)"

enum_type="$(qd "SELECT COLUMN_TYPE FROM information_schema.columns WHERE table_schema='$DB' AND table_name='memory_items' AND column_name='item_type'")"
enum_values="$(sed -e "s/^enum(//" -e "s/)\$//" -e "s/'//g" <<<"$enum_type")"
expected_enum="style,dialect,tone,phrase_preferred,topic_preferred,topic_forbidden,reply_rule,example_approved,business_fact,safety_keyword"
enum_count="$(awk -F, '{print NF}' <<<"$enum_values")"
record "T-06 item_type عشرة أنواع بالترتيب" "$expected_enum" "$enum_values (n=$enum_count)" \
  "$([[ "$enum_values" == "$expected_enum" && "$enum_count" == "10" ]] && echo 1 || echo 0)"

WS="$(printf '%-26s' '01JVERIFYWS0001' | tr ' ' '0')"
SUBJ="$(printf '%-26s' '01JVERIFYSUBJ01' | tr ' ' '0')"
MID1="$(printf '%-26s' '01JVERIFYMEM001' | tr ' ' '0')"
MID2="$(printf '%-26s' '01JVERIFYMEM002' | tr ' ' '0')"
MID3="$(printf '%-26s' '01JVERIFYMEM003' | tr ' ' '0')"
AP1="$(printf '%-26s' '01JVERIFYAPPR01' | tr ' ' '0')"
AP2="$(printf '%-26s' '01JVERIFYAPPR02' | tr ' ' '0')"
FAKE_WS="$(printf '%-26s' '01JFAKEWS000001' | tr ' ' '0')"

sqlrun "INSERT INTO workspaces (id,name,slug) VALUES ('$WS','verify workspace','verify-ws')" >/dev/null
ws_rows="$(qd "SELECT COUNT(*) FROM workspaces WHERE id='$WS'")"

insert_fact="$(sqlrun "INSERT INTO memory_items (id,workspace_id,item_type,content) VALUES ('$MID1','$WS','business_fact','pharmacy opens 9am to 11pm')")"
fact_rows="$(qd "SELECT COUNT(*) FROM memory_items WHERE workspace_id='$WS' AND item_type='business_fact'")"
record "T-07 business_fact ⇒ صف واحد" "1" "rows=$fact_rows" "$([[ "$fact_rows" == "1" ]] && echo 1 || echo 0)"

insert_old="$(sqlrun "INSERT INTO memory_items (id,workspace_id,item_type,content) VALUES ('$MID2','$WS','vocabulary','old value')")"
record "T-08 قيمة قديمة vocabulary ⇒ ERROR 1265" "ERROR 1265" "$insert_old" "$(grep -q 'ERROR 1265' <<<"$insert_old" && echo 1 || echo 0)"

insert_conf="$(sqlrun "INSERT INTO memory_items (id,workspace_id,item_type,content,confidence) VALUES ('$MID3','$WS','tone','x',1.5)")"
record "T-09 confidence=1.5 ⇒ ERROR 3819 (ck_mem_conf)" "ERROR 3819" "$insert_conf" "$(grep -q 'ERROR 3819' <<<"$insert_conf" && echo 1 || echo 0)"

sqlrun "INSERT INTO approvals (id,workspace_id,subject_type,subject_id,reason) VALUES ('$AP1','$WS','post','$SUBJ','manual_review')" >/dev/null
insert_dup="$(sqlrun "INSERT INTO approvals (id,workspace_id,subject_type,subject_id,reason) VALUES ('$AP2','$WS','post','$SUBJ','manual_review')")"
open_rows="$(qd "SELECT COUNT(*) FROM approvals WHERE workspace_id='$WS' AND status='open'")"
record "T-10 موافقة ثانية مفتوحة لنفس الموضوع ⇒ ERROR 1062" "ERROR 1062 · open=1" "$insert_dup · open=$open_rows" \
  "$(grep -q 'ERROR 1062' <<<"$insert_dup" && [[ "$open_rows" == "1" ]] && echo 1 || echo 0)"

insert_fake="$(sqlrun "INSERT INTO memory_items (id,workspace_id,item_type,content) VALUES ('${MID1:0:25}4','$FAKE_WS','tone','orphan')")"
record "T-11 workspace وهمي ⇒ ERROR 1452" "ERROR 1452" "$insert_fake" "$(grep -q 'ERROR 1452' <<<"$insert_fake" && echo 1 || echo 0)"

sqlrun "DELETE FROM workspaces WHERE id='$WS'" >/dev/null
total_rows=0
nonzero=""
for t in $(qd "SELECT table_name FROM information_schema.tables WHERE table_schema='$DB' AND table_name <> 'alembic_version' ORDER BY table_name"); do
  c="$(qd "SELECT COUNT(*) FROM \`$t\`")"
  total_rows=$((total_rows + c))
  [[ "$c" != "0" ]] && nonzero+="$t=$c "
done
record "T-12 DELETE workspaces ⇒ كل الجداول صفرًا" "total=0" "total=$total_rows ${nonzero}" "$([[ "$total_rows" == "0" ]] && echo 1 || echo 0)"

echo
for line in "${RESULTS[@]}"; do echo "$line"; done
echo
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  echo "RESULT: ALL CHECKS PASSED"
  exit 0
else
  echo "RESULT: FAILURES PRESENT"
  exit 1
fi
