#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"

BASE_IP="10.0.1"
FIRST_NODE_IP="${BASE_IP}.20"

OUTPUT_DIR=/root/benchmark/results/tidb_${NODE_COUNT}
QUERIES_DIR=/root/benchmark/queries/tpch

mkdir -p "$OUTPUT_DIR"

MYSQL="mysql -h ${FIRST_NODE_IP} -P 4000 -u root"

$MYSQL --database=tpch -e "SELECT * FROM information_schema.cluster_info;" \
  > "$OUTPUT_DIR/cluster_info.txt";

$MYSQL --database=tpch -e "SELECT * FROM information_schema.tikv_store_status;" \
  > "$OUTPUT_DIR/tikv_store_status.txt";

$MYSQL --database=tpch -e "SELECT * FROM information_schema.cluster_config;" \
  > "$OUTPUT_DIR/cluster_config.txt";

$MYSQL --database=tpch -e "SELECT * FROM information_schema.cluster_hardware;" \
  > "$OUTPUT_DIR/cluster_hardware.txt";\

$MYSQL --database=tpch -e "SHOW IMPORT JOBS;" \
  > "$OUTPUT_DIR/import_jobs.txt";

mkdir -p $OUTPUT_DIR/plans
for sql_file in "$QUERIES_DIR"/q*.sql; do
  q=$(basename "$sql_file" .sql)
  echo "  EXPLAIN $q"

  query=$(cat "$sql_file")

  $MYSQL --database=tpch -e "EXPLAIN FORMAT="verbose" ${query}" \
    > "$OUTPUT_DIR/plans/${q}_verbose.txt";

  $MYSQL --database=tpch -e "EXPLAIN ANALYZE ${query}" \
    > "$OUTPUT_DIR/plans/${q}_analyze.txt";
done
