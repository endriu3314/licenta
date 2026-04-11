#!/bin/bash
set -euo pipefail

DB_TYPE="${1}"
NODE_COUNT="${2}"
SCALE_FACTOR="${3}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "${DB_TYPE} - ${NODE_COUNT} nodes"

echo "[1/6] Teardown..."
"$SCRIPT_DIR/${DB_TYPE}/teardown.sh" "$NODE_COUNT"

echo "[2/6] Install..."
"$SCRIPT_DIR/${DB_TYPE}/install.sh" "$NODE_COUNT"

echo "[3/6] Load data..."
"$SCRIPT_DIR/${DB_TYPE}/load-data.sh" "$NODE_COUNT" "$SCALE_FACTOR"

echo "[4/6] Collecting metadata..."
"$SCRIPT_DIR/${DB_TYPE}/collect-metadata.sh" "$NODE_COUNT"

echo "[5/6] Running benchmark..."
cd /root/benchmark
java -jar benchmark-1.jar \
 --nodes="$NODE_COUNT"

echo "[6/6] Teardown..."
"$SCRIPT_DIR/${DB_TYPE}/teardown.sh" "$NODE_COUNT"

echo "  Done: ${DB_TYPE} ${NODE_COUNT} nodes"
echo "  Results in /root/benchmark/results/"
