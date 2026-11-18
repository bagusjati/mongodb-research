#!/usr/bin/env bash
# Pemakaian: bash 30_run.sh <config> <scenario> <level> <run_no>
#   scenario users:    level = jumlah thread (USERS_LEVELS)
#   scenario requests: level = loop per thread (REQUESTS_LEVELS) x 10 thread
#   scenario payload:  level = ukuran body (PAYLOAD_LEVELS), thread = PAYLOAD_THREADS
# Tiap run: koleksi dikosongkan, docker stats dicatat tiap STATS_INTERVAL_S detik, JMeter non-GUI, hasil ditarik ke OUT_DIR.
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
C="$1"; S="$2"; L="$3"; R="$4"; VM=$(vm_app "$C"); IP=$(ip_of "$VM"); SVC=$(svc_of "$C")
ID="${C}_${S}_${L}_run$(printf '%02d' "$R")"; DEST="$OUT_DIR/$C/$S"; mkdir -p "$DEST"
JMX="$REMOTE_BENCH_DIR/jmx"; STATS="$REMOTE_TMP_DIR/stats_$ID"
# 1) kosongkan koleksi (sharded: drop lalu shard ulang dengan key yang sama)
if [[ "$C" == sharded || "$C" == shardedreplica ]]; then
  gsh "$VM" "cd $REMOTE_APP_DIR && sudo docker compose exec -T $SVC mongosh --quiet --eval 'db.getSiblingDB(\"$DB_NAME\").users.drop(); sh.shardCollection(\"$DB_NAME.users\",{_id:\"hashed\"})' >/dev/null"
else
  gsh "$VM" "cd $REMOTE_APP_DIR && sudo docker compose exec -T $SVC mongosh --quiet --eval 'db.getSiblingDB(\"$DB_NAME\").users.drop()' >/dev/null"
fi
# 2) docker stats di latar belakang
gsh "$VM" "nohup bash -c 'while true; do sudo docker stats --no-stream --format \"{{.Name}},{{.CPUPerc}},{{.MemUsage}}\" | sed \"s/^/\$(date +%s),/\"; sleep $STATS_INTERVAL_S; done' > $STATS.csv 2>/dev/null & echo \$! > $STATS.pid"
# 3) JMeter
case "$S" in
  users)    ARGS="-t $JMX/users.jmx -Jthreads=$L";;
  requests) ARGS="-t $JMX/requests.jmx -Jloops=$L";;
  payload)  ARGS="-t $JMX/payload.jmx -Jthreads=$PAYLOAD_THREADS -Jbodyfile=$JMX/body_$L.json";;
  *) echo "skenario tidak dikenal: $S"; exit 1;;
esac
T0=$(date +%s)
gsh "$VM_JMETER" "ulimit -n 1048576; ulimit -u unlimited; rm -f $REMOTE_BENCH_DIR/$ID.jtl && \
  HEAP='$JMETER_HEAP' $REMOTE_JMETER_HOME/bin/jmeter -n $ARGS -Jhost=$IP -Jport=$APP_PORT -l $REMOTE_BENCH_DIR/$ID.jtl -j $REMOTE_BENCH_DIR/$ID.log 2>&1 | grep -E 'summary =|Err:|Tidying' | tail -2"
T1=$(date +%s)
# 4) hentikan stats, tarik hasil
gsh "$VM" "sudo kill \$(cat $STATS.pid) 2>/dev/null || true"
gcloud compute scp --zone "$ZONE" --quiet "$VM_JMETER:$REMOTE_BENCH_DIR/$ID.jtl" "$VM_JMETER:$REMOTE_BENCH_DIR/$ID.log" "$DEST/"
gcloud compute scp --zone "$ZONE" --quiet "$VM:$STATS.csv" "$DEST/"
gsh "$VM_JMETER" "rm -f $REMOTE_BENCH_DIR/$ID.jtl $REMOTE_BENCH_DIR/$ID.log"
echo "$ID,$T0,$T1,$((T1-T0))" >> "$OUT_DIR/runlog.csv"
echo "selesai $ID ($((T1-T0)) s)"
