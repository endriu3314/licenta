#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"
BASE_IP="10.0.1"

echo "Tearing down CockroachDB"

for i in $(seq 0 $((NODE_COUNT - 1))); do
  IP="${BASE_IP}.$((20 + i))"
  echo "Stopping db-node-${i} [${IP}]"
  ssh root@"$IP" bash <<'REMOTE'
  systemctl stop cockroach 2>/dev/null || true
  systemctl disable cockroach 2>/dev/null || true
  rm -rf /var/lib/cockroach/*
  rm -f /etc/systemd/system/cockroach.service
  systemctl daemon-reload
REMOTE
done
