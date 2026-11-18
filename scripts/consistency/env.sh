#!/usr/bin/env bash
# Parameter uji konsistensi replikasi lintas region. Setiap nilai dapat ditimpa lewat variabel lingkungan.
: "${PROJECT_ID:?PROJECT_ID belum diisi (id project GCP)}"
export PROJECT_ID
export ZONE_PRIMARY="${ZONE_PRIMARY:-asia-southeast1-b}"     # primary
export ZONE_SECONDARY="${ZONE_SECONDARY:-us-central1-a}"     # secondary
export MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-16}"
export VCPUS="${VCPUS:-16}"                                   # dipakai untuk menghitung batas CPU 50%, 10%, 1%
export IMAGE_FAMILY="${IMAGE_FAMILY:-ubuntu-2204-lts}"
export IMAGE_PROJECT="${IMAGE_PROJECT:-ubuntu-os-cloud}"
export DISK_GB="${DISK_GB:-50}"
export VM_PRIMARY="${VM_PRIMARY:-mongo-primary}"
export VM_SECONDARY="${VM_SECONDARY:-mongo-secondary}"
export MONGO_IMAGE="${MONGO_IMAGE:-mongo:7.0.0}"
export RS_NAME="${RS_NAME:-rs0}"
export MONGO_PORT="${MONGO_PORT:-27017}"
export CONTAINER="${CONTAINER:-mongo}"
export NETWORK="${NETWORK:-default}"
export NET_TAG="${NET_TAG:-mongo-rs}"
export FIREWALL_RULE="${FIREWALL_RULE:-allow-mongo-rs-internal}"
export SOURCE_RANGES="${SOURCE_RANGES:-10.0.0.0/8}"
export NET_IF="${NET_IF:-ens4}"                               # antarmuka jaringan VM untuk tc netem
export DELAY_MS="${DELAY_MS:-1000}"
export SCENARIOS="${SCENARIOS:-baseline delay cpu50 cpu10 cpu1}"
export SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export OUT_DIR="${OUT_DIR:-$HOME/consistency_results}"; mkdir -p "$OUT_DIR"
export STATUS_FILE="${STATUS_FILE:-$OUT_DIR/status_cons.txt}"
export REMOTE_TMP_DIR="${REMOTE_TMP_DIR:-/var/tmp}"
export REMOTE_DATA_DIR="${REMOTE_DATA_DIR:-/data/mongo}"
sshp() { gcloud compute ssh "$VM_PRIMARY"   --zone "$ZONE_PRIMARY"   --quiet --command "$1"; }
sshs() { gcloud compute ssh "$VM_SECONDARY" --zone "$ZONE_SECONDARY" --quiet --command "$1"; }
ip_p() { gcloud compute instances describe "$VM_PRIMARY"   --zone "$ZONE_PRIMARY"   --format='get(networkInterfaces[0].networkIP)'; }
ip_s() { gcloud compute instances describe "$VM_SECONDARY" --zone "$ZONE_SECONDARY" --format='get(networkInterfaces[0].networkIP)'; }
