#!/usr/bin/env bash
# Membuat VM aplikasi (satu per konfigurasi) dan satu VM JMeter di zona yang sama.
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
gcloud config set project "$PROJECT_ID" >/dev/null
# startup script VM JMeter diberi parameter lewat baris variabel yang disisipkan setelah shebang
TMP=$(mktemp -d)
{ head -1 "$SCRIPT_DIR/startup_jmeter.sh"
  echo "JMETER_VERSION=$JMETER_VERSION"; echo "JMETER_HOME=$REMOTE_JMETER_HOME"; echo "BENCH_DIR=$REMOTE_BENCH_DIR"; echo "TMP_DIR=$REMOTE_TMP_DIR"
  tail -n +2 "$SCRIPT_DIR/startup_jmeter.sh"; } > "$TMP/startup_jmeter.sh"
{ head -1 "$SCRIPT_DIR/startup_app.sh"; echo "TMP_DIR=$REMOTE_TMP_DIR"; tail -n +2 "$SCRIPT_DIR/startup_app.sh"; } > "$TMP/startup_app.sh"
for c in $CONFIGS; do
  n=$(vm_app "$c")
  gcloud compute instances describe "$n" --zone "$ZONE" >/dev/null 2>&1 && { echo "$n sudah ada"; continue; }
  gcloud compute instances create "$n" --zone "$ZONE" --machine-type "$MACHINE_APP" \
    --image-family "$IMAGE_FAMILY" --image-project "$IMAGE_PROJECT" \
    --boot-disk-size "${APP_DISK_GB}GB" --boot-disk-type pd-balanced --tags "$NET_TAG" \
    --metadata-from-file startup-script="$TMP/startup_app.sh"
done
if ! gcloud compute instances describe "$VM_JMETER" --zone "$ZONE" >/dev/null 2>&1; then
  gcloud compute instances create "$VM_JMETER" --zone "$ZONE" --machine-type "$MACHINE_JMETER" \
    --image-family "$IMAGE_FAMILY" --image-project "$IMAGE_PROJECT" \
    --boot-disk-size "${JMETER_DISK_GB}GB" --boot-disk-type pd-standard --tags "$NET_TAG" \
    --metadata-from-file startup-script="$TMP/startup_jmeter.sh"
fi
rm -rf "$TMP"
echo "menunggu startup (3 sampai 5 menit)..."
for n in $(for c in $CONFIGS; do vm_app "$c"; done) "$VM_JMETER"; do
  until gsh "$n" "test -f $REMOTE_TMP_DIR/setup_done" >/dev/null 2>&1; do sleep 20; echo "  $n belum siap"; done
  echo "  $n siap"
done
gcloud compute instances list --filter="tags.items=$NET_TAG" --format="table(name,machineType.basename(),networkInterfaces[0].networkIP,status)"
