#!/usr/bin/env bash
# Mencatat versi dan keadaan tiap konfigurasi: db.version(), docker, ulimit di container server, status shard.
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"; mkdir -p "$OUT_DIR/meta"
for c in $CONFIGS; do
  VM=$(vm_app "$c"); SVC=$(svc_of "$c")
  {
    echo "== $c $(date -u +%FT%TZ)"; gsh "$VM" "cd $REMOTE_APP_DIR && sudo docker compose exec -T $SVC mongosh --quiet --eval 'print(\"mongodb\", db.version())'; sudo docker version --format 'docker {{.Server.Version}}'; sudo docker compose exec -T server sh -c 'ulimit -n'; nproc; free -g | head -2; sudo docker compose ps --format '{{.Name}} {{.Image}} {{.Status}}'"
    if [[ "$c" == sharded || "$c" == shardedreplica ]]; then
      gsh "$VM" "cd $REMOTE_APP_DIR && sudo docker compose exec -T router01 mongosh --quiet --eval 'db.getSiblingDB(\"$DB_NAME\").users.getShardDistribution()'"
    fi
    if [[ "$c" == replica ]]; then
      gsh "$VM" "cd $REMOTE_APP_DIR && sudo docker compose exec -T mongo1 mongosh --quiet --eval 'const c=rs.conf(); c.members.forEach(m=>print(m.host,m.priority)); printjson(db.adminCommand({getDefaultRWConcern:1}).defaultWriteConcern)'"
    fi
  } | tee "$OUT_DIR/meta/$c.txt"
done
gsh "$VM_JMETER" "java -version 2>&1 | head -1; $REMOTE_JMETER_HOME/bin/jmeter --version 2>/dev/null | grep -o '5\.[0-9.]*' | head -1; ulimit -n; sysctl net.ipv4.ip_local_port_range" | tee "$OUT_DIR/meta/jmeter.txt"
