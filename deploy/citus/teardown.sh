#!/bin/bash
set -euo pipefail

NODE_COUNT="${1:?Usage: ./teardown.sh <node_count>}"
BASE_IP="10.0.1"

echo "Tearing down Citus"

for i in $(seq 0 $((NODE_COUNT - 1))); do
  IP="${BASE_IP}.$((20 + i))"
  echo "Cleaning db-node-${i}..."
  ssh root@"$IP" bash <<'REMOTE'
    systemctl stop postgresql 2>/dev/null || true
    rm -rf /var/lib/postgresql /etc/postgresql
    systemctl daemon-reload
REMOTE
done
