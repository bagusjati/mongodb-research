#!/usr/bin/env bash
# Membuat dua VM di dua region dan membuka port MongoDB untuk lalu lintas internal VPC.
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
gcloud config set project "$PROJECT_ID"
# parameter startup script disisipkan setelah shebang
TMP=$(mktemp -d)
{ head -1 "$SCRIPT_DIR/02_setup_node.sh"
  echo "MONGO_IMAGE=$MONGO_IMAGE"; echo "RS_NAME=$RS_NAME"; echo "CONTAINER=$CONTAINER"; echo "DATA_DIR=$REMOTE_DATA_DIR"; echo "TMP_DIR=$REMOTE_TMP_DIR"
  tail -n +2 "$SCRIPT_DIR/02_setup_node.sh"; } > "$TMP/setup_node.sh"
for pair in "$VM_PRIMARY:$ZONE_PRIMARY" "$VM_SECONDARY:$ZONE_SECONDARY"; do
  name="${pair%%:*}"; zone="${pair##*:}"
  if ! gcloud compute instances describe "$name" --zone "$zone" >/dev/null 2>&1; then
    gcloud compute instances create "$name" --zone "$zone" \
      --machine-type "$MACHINE_TYPE" \
      --image-family "$IMAGE_FAMILY" --image-project "$IMAGE_PROJECT" \
      --boot-disk-size "${DISK_GB}GB" --boot-disk-type pd-balanced \
      --network "$NETWORK" --tags "$NET_TAG" \
      --metadata-from-file startup-script="$TMP/setup_node.sh"
  else
    echo "VM $name sudah ada, dilewati."
  fi
done
rm -rf "$TMP"
# Port MongoDB antar VM (VPC GCP bersifat global, IP internal dapat dipakai lintas region).
if ! gcloud compute firewall-rules describe "$FIREWALL_RULE" >/dev/null 2>&1; then
  gcloud compute firewall-rules create "$FIREWALL_RULE" \
    --network "$NETWORK" --direction INGRESS --action ALLOW \
    --rules "tcp:$MONGO_PORT" --source-ranges "$SOURCE_RANGES" --target-tags "$NET_TAG"
fi
echo "Menunggu startup script selesai (sekitar 2 sampai 3 menit)..."
for pair in "$VM_PRIMARY:$ZONE_PRIMARY" "$VM_SECONDARY:$ZONE_SECONDARY"; do
  name="${pair%%:*}"; zone="${pair##*:}"
  until gcloud compute ssh "$name" --zone "$zone" --quiet --command "test -f $REMOTE_TMP_DIR/setup_done" >/dev/null 2>&1; do
    sleep 15; echo "  $name belum siap..."
  done
  echo "  $name siap."
done
echo "IP internal:"
gcloud compute instances list --filter="tags.items=$NET_TAG" --format="table(name,zone.basename(),networkInterfaces[0].networkIP,networkInterfaces[0].accessConfigs[0].natIP)"
