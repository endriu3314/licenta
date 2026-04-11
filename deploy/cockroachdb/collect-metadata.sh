#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"

BASE_IP="10.0.1"
FIRST_NODE_IP="${BASE_IP}.20"

OUTPUT_DIR=/root/benchmark/results/crdb_${NODE_COUNT}
QUERIES_DIR=/root/benchmark/queries/tpch

mkdir -p "$OUTPUT_DIR"

crdb_sql() {
 ssh root@"$FIRST_NODE_IP" "cockroach sql --insecure --host=localhost:26257 $*"
}

crdb_sql -e "\"SHOW ALL CLUSTER SETTINGS;\"" \
  > "$OUTPUT_DIR/cluster_settings.txt"

mkdir -p $OUTPUT_DIR/plans
for sql_file in "$QUERIES_DIR"/q*.sql; do
  q=$(basename "$sql_file" .sql)
  echo "  EXPLAIN $q"

  query=$(cat "$sql_file")

  crdb_sql --database=tpch -e "\"EXPLAIN (VERBOSE) ${query}\"" \
    > "$OUTPUT_DIR/plans/${q}_verbose.txt"

  crdb_sql --database=tpch -e "\"EXPLAIN (DISTSQL) ${query}\"" \
    > "$OUTPUT_DIR/plans/${q}_distsql.txt"
done