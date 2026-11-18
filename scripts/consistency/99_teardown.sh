#!/usr/bin/env bash
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
gcloud compute instances delete "$VM_PRIMARY"   --zone "$ZONE_PRIMARY"   --quiet
gcloud compute instances delete "$VM_SECONDARY" --zone "$ZONE_SECONDARY" --quiet
gcloud compute firewall-rules delete "$FIREWALL_RULE" --quiet
