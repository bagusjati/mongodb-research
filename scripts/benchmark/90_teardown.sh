#!/usr/bin/env bash
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
for c in $CONFIGS; do gcloud compute instances delete "$(vm_app "$c")" --zone "$ZONE" --quiet || true; done
gcloud compute instances delete "$VM_JMETER" --zone "$ZONE" --quiet || true
