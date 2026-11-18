#!/usr/bin/env bash
# Orkestrasi uji konsistensi. Status ditulis ke STATUS_FILE.
set -uo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
st() { echo "$(date -u +%FT%TZ) $*" | tee -a "$STATUS_FILE"; }
st "START"
bash "$SCRIPT_DIR/01_provision.sh" && st "provision ok" || { st "provision FAILED"; exit 1; }
bash "$SCRIPT_DIR/03_init_rs.sh" | tee "$OUT_DIR/init_rs.txt"; st "init rs ok"
bash "$SCRIPT_DIR/04_run_scenario.sh" baseline 99 200 100 && st "smoke ok" || { st "smoke FAILED"; exit 1; }
RUNS="${RUNS:-5}" N="${N:-1000}" RATE="${RATE:-100}" bash "$SCRIPT_DIR/05_run_all.sh" && st "all scenarios ok"
python3 "$SCRIPT_DIR/06_analyze.py" "$OUT_DIR" > "$OUT_DIR/summary.txt" 2>&1 && st "analyze ok"
bash "$SCRIPT_DIR/99_teardown.sh" && st "teardown ok"
st "ALL DONE"
