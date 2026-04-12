#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"

BASE_IP="10.0.1"
FIRST_NODE_IP="${BASE_IP}.20"

OUTPUT_DIR=/root/benchmark/results/citus_${NODE_COUNT}
QUERIES_DIR=/root/benchmark/queries/tpch

mkdir -p "$OUTPUT_DIR"

PSQL="psql -h ${FIRST_NODE_IP} -U postgres"

$PSQL -c "SELECT * FROM pg_dist_node;" \
    > "$OUTPUT_DIR/dist_nodes.txt"

$PSQL -c "SELECT * FROM citus_shards;" \
    > "$OUTPUT_DIR/citus_shards.txt"

$PSQL -c "SELECT * FROM pg_dist_placement;" \
    > "$OUTPUT_DIR/dist_placement.txt"

mkdir -p $OUTPUT_DIR/plans
for sql_file in "$QUERIES_DIR"/q*.sql; do
    q=$(basename "$sql_file" .sql)
    echo "  EXPLAIN $q"

    query=$(cat "$sql_file")

    if ! $PSQL -c "EXPLAIN (VERBOSE) ${query}" \
        > "$OUTPUT_DIR/plans/${q}_verbose.txt" 2>&1; then
        echo "    $q EXPLAIN failed (unsupported query)"
    fi

    if ! $PSQL -c "EXPLAIN (VERBOSE, ANALYZE) ${query}" \
        > "$OUTPUT_DIR/plans/${q}_analyze.txt" 2>&1; then
        echo "    $q EXPLAIN ANALYZE failed (unsupported query)"
    fi
done