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