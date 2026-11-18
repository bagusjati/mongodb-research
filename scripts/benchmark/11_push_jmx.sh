#!/usr/bin/env bash
# Menyalin test plan JMeter dan berkas body ke VM JMeter.
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
gsh "$VM_JMETER" "rm -rf $REMOTE_BENCH_DIR/jmx && mkdir -p $REMOTE_BENCH_DIR/jmx"
for f in users.jmx requests.jmx payload.jmx; do gscp "$JMX_SRC_DIR/$f" "$VM_JMETER:$REMOTE_BENCH_DIR/jmx/"; done
for p in $PAYLOAD_LEVELS; do gscp "$JMX_SRC_DIR/body_$p.json" "$VM_JMETER:$REMOTE_BENCH_DIR/jmx/"; done
gsh "$VM_JMETER" "ls $REMOTE_BENCH_DIR/jmx"
