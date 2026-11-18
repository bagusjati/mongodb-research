#!/usr/bin/env bash
# Skenario users dan payload, RUNS kali, berurutan untuk semua konfigurasi (satu VM JMeter).
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"; RUNS="${RUNS:-5}"
for r in $(seq 1 "$RUNS"); do
  for c in $CONFIGS; do
    for n in $USERS_LEVELS;   do bash "$SCRIPT_DIR/30_run.sh" "$c" users "$n" "$r"; done
    for p in $PAYLOAD_LEVELS; do bash "$SCRIPT_DIR/30_run.sh" "$c" payload "$p" "$r"; done
  done
done
