#!/usr/bin/env bash
# Orkestrasi utama, dijalankan di mesin pengendali (misalnya di dalam tmux). Status ditulis ke STATUS_FILE.
set -uo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
st() { echo "$(date -u +%FT%TZ) $*" | tee -a "$STATUS_FILE"; }
st "START"
bash "$SCRIPT_DIR/10_provision.sh" && st "provision ok" || { st "provision FAILED"; exit 1; }
bash "$SCRIPT_DIR/11_push_jmx.sh" && st "jmx ok"
for c in $CONFIGS; do bash "$SCRIPT_DIR/20_deploy.sh" "$c" && st "deploy $c ok" || st "deploy $c FAILED"; done
bash "$SCRIPT_DIR/40_meta.sh" && st "meta ok"
bash "$SCRIPT_DIR/30_run.sh" standalone users 100 99 && st "smoke ok" || { st "smoke FAILED"; exit 1; }
RUNS="${RUNS:-5}" bash "$SCRIPT_DIR/31_short_all.sh" && st "short scenarios (users, payload) ok"
for r in $(seq 1 "${REQUEST_PASSES:-3}"); do bash "$SCRIPT_DIR/32_requests_parallel.sh" "$r" && st "requests pass $r ok"; done
# uji terisolasi: Replica dengan w:1, dan Standalone dengan pool driver 1000 (run 11 sampai 13)
bash "$SCRIPT_DIR/20_deploy.sh" replica "mongodb://mongo1:27017,mongo2:27018,mongo3:27019/?replicaSet=rs0&w=1" && st "deploy replica w1 ok"
for r in 11 12 13; do bash "$SCRIPT_DIR/30_run.sh" replica requests 100000 "$r"; done; st "isolated w1 ok"
bash "$SCRIPT_DIR/20_deploy.sh" standalone "mongodb://mongodb:27017/?maxPoolSize=1000" && st "deploy standalone pool1000 ok"
for r in 11 12 13; do bash "$SCRIPT_DIR/30_run.sh" standalone users 100000 "$r"; done; st "isolated pool ok"
python3 "$SCRIPT_DIR/50_analyze.py" "$OUT_DIR" > "$OUT_DIR/summary.txt" 2>&1 && st "analyze ok"
st "ALL DONE"
