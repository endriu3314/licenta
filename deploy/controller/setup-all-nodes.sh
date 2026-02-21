#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"
BASE_IP="10.0.1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"

echo "Setting up ${NODE_COUNT} nodes"

for i in $(seq 0 $((NODE_COUNT - 1))); do\
  IP="${BASE_IP}.$((20 + i))"
  echo "Setting up db-node-${i} [${IP}]..."
  ssh root@"$IP" "bash -s" < "$DEPLOY_DIR/common/setup-node.sh"
done

for i in $(seq 0 $((NODE_COUNT - 1))); do
  IP="10.0.1.$((20 + i))"
  echo "Rebooting db-node-${i}..."
  ssh root@"$IP" "reboot" 2>/dev/null || true
done

echo "Waiting 30s for nodes to come back..."
sleep 30

for i in $(seq 0 $((NODE_COUNT - 1))); do
  IP="10.0.1.$((20 + i))"
  echo -n "  db-node-${i}..."
  until ssh -o StrictHostKeyChecking=no root@"$IP" "echo ok" &>/dev/null; do
    echo -n "."
    sleep 5
  done
  echo " up"
done

reboot
