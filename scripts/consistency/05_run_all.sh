#!/usr/bin/env bash
# Menjalankan semua skenario (SCENARIOS), masing-masing RUNS kali.
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
RUNS="${RUNS:-5}"; N="${N:-1000}"; RATE="${RATE:-100}"
for s in $SCENARIOS; do
  for r in $(seq 1 "$RUNS"); do
    bash "$SCRIPT_DIR/04_run_scenario.sh" "$s" "$r" "$N" "$RATE"
  done
done
