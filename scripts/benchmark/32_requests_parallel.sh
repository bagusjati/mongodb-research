#!/usr/bin/env bash
# Skenario total request: semua konfigurasi dijalankan bersamaan (10 thread masing-masing), satu pass = $1.
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"; R="$1"
for loops in $REQUESTS_LEVELS; do
  pids=()
  for c in $CONFIGS; do bash "$SCRIPT_DIR/30_run.sh" "$c" requests "$loops" "$R" > "$OUT_DIR/log_${c}_requests_${loops}_$R.txt" 2>&1 & pids+=($!); done
  for p in "${pids[@]}"; do wait "$p"; done
  echo "pass $R loops $loops selesai"
done
