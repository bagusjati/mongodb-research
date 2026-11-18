#!/usr/bin/env bash
# Pemakaian: bash 20_deploy.sh <config> [MONGO_URI_OVERRIDE]
# Menyalin kode konfigurasi, mengunci image MongoDB, menulis .env (APP_DIR, MONGO_URI), compose up, inisialisasi sharding, uji koneksi aplikasi.
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
C="$1"; URI="${2:-}"; VM=$(vm_app "$C"); SRC="$APP_SRC_DIR/$(dir_of "$C")"
TMP=$(mktemp -d); cp -r "$SRC" "$TMP/app"
sed -i -E "s#image: mongo:7(\.0)?\$#image: $MONGO_IMAGE#" "$TMP/app/docker-compose.yaml"
gsh "$VM" "rm -rf $REMOTE_TMP_DIR/app_upload"
gscp "$TMP/app" "$VM:$REMOTE_TMP_DIR/app_upload"
gsh "$VM" "sudo rm -rf $REMOTE_APP_DIR && sudo mv $REMOTE_TMP_DIR/app_upload $REMOTE_APP_DIR && sudo chown -R \$USER $REMOTE_APP_DIR"
gsh "$VM" "cd $REMOTE_APP_DIR && printf 'APP_DIR=%s\nMONGO_URI=%s\n' '$REMOTE_APP_DIR' '$URI' > $REMOTE_APP_DIR/.env; sudo docker compose down -v --remove-orphans >/dev/null 2>&1 || true; sudo docker compose up -d --build 2>&1 | tail -3"
case "$C" in
  sharded|shardedreplica)
    gsh "$VM" "cd $REMOTE_APP_DIR && sleep 15 && \
      sudo docker compose exec -T configsvr01 sh -c 'mongosh --quiet < /scripts/init-configserver.js' && \
      sudo docker compose exec -T shard01-a sh -c 'mongosh --quiet < /scripts/init-shard01.js' && \
      sudo docker compose exec -T shard02-a sh -c 'mongosh --quiet < /scripts/init-shard02.js' && \
      sleep 25 && sudo docker compose exec -T router01 sh -c 'mongosh --quiet < /scripts/init-router.js' && \
      sudo docker compose restart server >/dev/null" ;;
  replica) gsh "$VM" "sleep 30; cd $REMOTE_APP_DIR && sudo docker compose exec -T mongo1 mongosh --quiet --eval 'rs.status().members.forEach(m=>print(m.name,m.stateStr))'" ;;
esac
# uji koneksi aplikasi
OUT=$(gsh "$VM" "for i in \$(seq 1 30); do curl -s -o /dev/null -w '%{http_code}\n' -X POST localhost:$APP_PORT/users -H 'Content-Type: application/json' -d '{\"name\":\"probe\",\"email\":\"probe@x.io\",\"password\":\"p\"}' | grep -q 200 && echo APP_OK && break; sleep 3; done")
rm -rf "$TMP"
echo "$OUT" | grep -q APP_OK || { echo "APP NOT RESPONDING on $VM"; gsh "$VM" "cd $REMOTE_APP_DIR && sudo docker compose ps; sudo docker compose logs --tail 20 server"; exit 1; }
echo "deploy $C: APP_OK"
