#!/usr/bin/env bash
# Pemakaian: bash 04_run_scenario.sh <scenario> <run_no> [N] [rate]
# scenario: baseline | delay (DELAY_MS pada lalu lintas primary ke secondary) | cpu50 | cpu10 | cpu1 (batas CPU mongod di secondary)
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
SCEN="$1"; RUN="$2"; N="${3:-1000}"; RATE="${4:-100}"
RUN_ID="${SCEN}_run$(printf '%02d' "$RUN")"
IP_S=$(ip_s); T="$REMOTE_TMP_DIR"
cpus() { python3 -c "print(round($VCPUS*$1/100, 2))"; }
# Bersihkan kondisi sebelumnya: hapus netem dan batas CPU.
sshp "sudo tc qdisc del dev $NET_IF root 2>/dev/null || true"
sshs "sudo tc qdisc del dev $NET_IF root 2>/dev/null || true; sudo docker update --cpus=0 $CONTAINER >/dev/null"
case "$SCEN" in
  baseline) ;;
  delay)
    # Delay hanya pada lalu lintas primary -> secondary (filter tujuan IP secondary), agar SSH tidak ikut lambat.
    sshp "sudo tc qdisc add dev $NET_IF root handle 1: prio && \
          sudo tc qdisc add dev $NET_IF parent 1:3 handle 30: netem delay ${DELAY_MS}ms && \
          sudo tc filter add dev $NET_IF protocol ip parent 1:0 prio 3 u32 match ip dst $IP_S/32 flowid 1:3" ;;
  cpu50) sshs "sudo docker update --cpus=$(cpus 50) $CONTAINER >/dev/null" ;;
  cpu10) sshs "sudo docker update --cpus=$(cpus 10) $CONTAINER >/dev/null" ;;
  cpu1)  sshs "sudo docker update --cpus=$(cpus 1)  $CONTAINER >/dev/null" ;;
  *) echo "scenario tidak dikenal: $SCEN"; exit 1 ;;
esac
LOCAL_TMP=$(mktemp -d)
sshp "chronyc tracking | egrep 'System time|RMS offset'" > "$LOCAL_TMP/ntp_${RUN_ID}_primary_before.txt"
sshs "chronyc tracking | egrep 'System time|RMS offset'" > "$LOCAL_TMP/ntp_${RUN_ID}_secondary_before.txt"
# Salin skrip, jalankan reader di secondary (background), lalu inserter di primary.
gcloud compute scp "$SCRIPT_DIR/reader.py"   "$VM_SECONDARY:$T/reader.py"   --zone "$ZONE_SECONDARY" --quiet
gcloud compute scp "$SCRIPT_DIR/inserter.py" "$VM_PRIMARY:$T/inserter.py"   --zone "$ZONE_PRIMARY"   --quiet
TIMEOUT=$(( N / RATE + 600 ))
sshs "nohup python3 $T/reader.py $RUN_ID $N $TIMEOUT $T $MONGO_PORT > $T/reader_${RUN_ID}.log 2>&1 &"
sleep 3
sshp "python3 $T/inserter.py $RUN_ID $N $RATE $T $MONGO_PORT"
until sshs "grep -q visible $T/reader_${RUN_ID}.log"; do sleep 5; done
sshs "cat $T/reader_${RUN_ID}.log"
sshp "chronyc tracking | egrep 'System time|RMS offset'" > "$LOCAL_TMP/ntp_${RUN_ID}_primary_after.txt"
sshs "chronyc tracking | egrep 'System time|RMS offset'" > "$LOCAL_TMP/ntp_${RUN_ID}_secondary_after.txt"
# Tarik hasil ke mesin pengendali.
mkdir -p "$OUT_DIR/$SCEN"
gcloud compute scp "$VM_SECONDARY:$T/visible_${RUN_ID}.csv" "$OUT_DIR/$SCEN/" --zone "$ZONE_SECONDARY" --quiet
gcloud compute scp "$VM_PRIMARY:$T/insert_${RUN_ID}.csv"    "$OUT_DIR/$SCEN/" --zone "$ZONE_PRIMARY"   --quiet
mv "$LOCAL_TMP"/ntp_${RUN_ID}_*.txt "$OUT_DIR/$SCEN/"; rm -rf "$LOCAL_TMP"
# Kembalikan kondisi.
sshp "sudo tc qdisc del dev $NET_IF root 2>/dev/null || true"
sshs "sudo docker update --cpus=0 $CONTAINER >/dev/null"
echo "selesai: $RUN_ID -> $OUT_DIR/$SCEN"
