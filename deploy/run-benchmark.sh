#!/bin/bash
set -euo pipefail

DB_TYPE="${1}"
NODE_COUNT="${2}"
SCALE_FACTOR="${3}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "${DB_TYPE} - ${NODE_COUNT} nodes"

echo "Ensure .env has ACTIVE_DB set"
echo -e "\nACTIVE_DB=${DB_TYPE}" >> .env

echo "[1/5] Teardown..."
"$SCRIPT_DIR/${DB_TYPE}/teardown.sh" "$NODE_COUNT"

echo "[2/5] Install..."
"$SCRIPT_DIR/${DB_TYPE}/install.sh" "$NODE_COUNT"

echo "[3/5] Load data..."
"$SCRIPT_DIR/${DB_TYPE}/load-data.sh" "$NODE_COUNT" "$SCALE_FACTOR"

echo "[4/5] Running benchmark..."
cd /root/benchmark
java -jar benchmark-1.jar \
  --nodes="$NODE_COUNT"

echo "[5/5] Teardown..."
"$SCRIPT_DIR/${DB_TYPE}/teardown.sh" "$NODE_COUNT"

echo "  Done: ${DB_TYPE} ${NODE_COUNT} nodes"
echo "  Reuslts in /root/benchmark/results/"
