#!/usr/bin/env bash
# Inisialisasi replica set: primary (priority 2) dan secondary (priority 1), lalu ukur RTT antar VM.
set -euo pipefail
source "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/env.sh"
IP_P=$(ip_p); IP_S=$(ip_s)
echo "primary=$IP_P secondary=$IP_S"
sshp "
sudo docker exec $CONTAINER mongosh --quiet --eval '
try { rs.status(); print(\"already initiated\") } catch (e) {
rs.initiate({_id: \"$RS_NAME\", members: [
  {_id: 0, host: \"$IP_P:$MONGO_PORT\", priority: 2},
  {_id: 1, host: \"$IP_S:$MONGO_PORT\", priority: 1}
]}) }'
for i in \$(seq 1 60); do
  sudo docker exec $CONTAINER mongosh --quiet --eval 'quit(db.hello().isWritablePrimary ? 0 : 1)' && break
  sleep 3
done
sudo docker exec $CONTAINER mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
"
sshp "ping -c 20 $IP_S" | tail -3
