#!/usr/bin/env bash
# Startup script tiap VM: Docker, chrony (NTP ke metadata.google.internal), pymongo, container mongod.
# MONGO_IMAGE, RS_NAME, CONTAINER, DATA_DIR dan TMP_DIR disisipkan oleh 01_provision.sh; nilai di bawah hanya cadangan.
set -euo pipefail
MONGO_IMAGE="${MONGO_IMAGE:-mongo:7.0.0}"; RS_NAME="${RS_NAME:-rs0}"; CONTAINER="${CONTAINER:-mongo}"
DATA_DIR="${DATA_DIR:-/data/mongo}"; TMP_DIR="${TMP_DIR:-/var/tmp}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io chrony python3-pip iproute2
pip3 install --quiet pymongo==4.8.0
systemctl enable --now docker chrony
grep -q "metadata.google.internal" /etc/chrony/chrony.conf || echo "server metadata.google.internal iburst prefer" >> /etc/chrony/chrony.conf
systemctl restart chrony
sleep 5
chronyc makestep || true
docker pull "$MONGO_IMAGE"
mkdir -p "$DATA_DIR"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" --restart unless-stopped \
  --network host -v "$DATA_DIR:/data/db" \
  "$MONGO_IMAGE" mongod --replSet "$RS_NAME" --bind_ip_all
touch "$TMP_DIR/setup_done"
