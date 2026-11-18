#!/usr/bin/env bash
# Parameter eksperimen benchmark. Setiap nilai dapat ditimpa lewat variabel lingkungan
# sebelum skrip dijalankan, misalnya: PROJECT_ID=my-project ZONE=us-central1-a bash 10_provision.sh
: "${PROJECT_ID:?PROJECT_ID belum diisi (id project GCP)}"
export PROJECT_ID
export ZONE="${ZONE:-asia-southeast1-b}"
export MACHINE_APP="${MACHINE_APP:-e2-standard-16}"
export MACHINE_JMETER="${MACHINE_JMETER:-e2-standard-16}"
export IMAGE_FAMILY="${IMAGE_FAMILY:-ubuntu-2204-lts}"
export IMAGE_PROJECT="${IMAGE_PROJECT:-ubuntu-os-cloud}"
export APP_DISK_GB="${APP_DISK_GB:-80}"
export JMETER_DISK_GB="${JMETER_DISK_GB:-100}"
export NET_TAG="${NET_TAG:-bench}"
export MONGO_IMAGE="${MONGO_IMAGE:-mongo:7.0.9}"     # satu tag tetap untuk keempat konfigurasi
export DB_NAME="${DB_NAME:-MyDatabase}"
export APP_PORT="${APP_PORT:-8080}"
export CONFIGS="${CONFIGS:-standalone replica sharded shardedreplica}"
export VM_PREFIX="${VM_PREFIX:-app-}"
export VM_JMETER="${VM_JMETER:-jmeter-01}"
export JMETER_VERSION="${JMETER_VERSION:-5.6.3}"
export JMETER_HEAP="${JMETER_HEAP:--Xms4g -Xmx40g}"
export PAYLOAD_THREADS="${PAYLOAD_THREADS:-100000}"
export USERS_LEVELS="${USERS_LEVELS:-100 1000 10000 100000}"
export REQUESTS_LEVELS="${REQUESTS_LEVELS:-1000 10000 100000 300000}"
export PAYLOAD_LEVELS="${PAYLOAD_LEVELS:-0.1kB 1kB 10kB}"
export STATS_INTERVAL_S="${STATS_INTERVAL_S:-5}"
# lokasi sumber dan keluaran di mesin pengendali
export SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# REPO_ROOT: path absolut repository. Bila tidak diisi, diambil dari git.
export REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)}"
: "${REPO_ROOT:?REPO_ROOT belum diisi (path absolut repository)}"
export APP_SRC_DIR="${APP_SRC_DIR:-$REPO_ROOT/app}"
export JMX_SRC_DIR="${JMX_SRC_DIR:-$REPO_ROOT/jmeter}"
export OUT_DIR="${OUT_DIR:-$HOME/benchmark_results}"; mkdir -p "$OUT_DIR"
export STATUS_FILE="${STATUS_FILE:-$OUT_DIR/status_main.txt}"
# lokasi di VM
export REMOTE_APP_DIR="${REMOTE_APP_DIR:-/opt/app}"
export REMOTE_BENCH_DIR="${REMOTE_BENCH_DIR:-/opt/bench}"
export REMOTE_JMETER_HOME="${REMOTE_JMETER_HOME:-/opt/jmeter}"
export REMOTE_TMP_DIR="${REMOTE_TMP_DIR:-/var/tmp}"
# nama VM dan direktori sumber per konfigurasi
vm_app() { echo "${VM_PREFIX}$1"; }
dir_of() { case "$1" in standalone|replica|sharded) echo "$1";; shardedreplica) echo "sharded-replica";; *) echo "konfigurasi tidak dikenal: $1" >&2; exit 1;; esac; }
svc_of() { case "$1" in standalone) echo mongodb;; replica) echo mongo1;; *) echo router01;; esac; }
gsh()  { gcloud compute ssh "$1" --zone "$ZONE" --quiet --command "$2"; }
gscp() { gcloud compute scp --zone "$ZONE" --quiet --recurse "$1" "$2"; }
ip_of(){ gcloud compute instances describe "$1" --zone "$ZONE" --format='get(networkInterfaces[0].networkIP)'; }
