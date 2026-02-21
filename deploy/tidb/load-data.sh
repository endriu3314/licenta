#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"
SCALE_FACTOR="${2}"
BASE_IP="10.0.1"
FIRST_NODE_IP="${BASE_IP}.20"
DATA_DIR="/root/benchmark/data/tpch/sf$SCALE_FACTOR"
SCHEMA_FILE="/root/benchmark/schemas/tpch/tidb/create_tables.sql"

echo "Loading TPC-H into TiDB"

MYSQL="mysql -h ${FIRST_NODE_IP} -P 4000 -u root"

echo "Creating database..."
$MYSQL -e "DROP DATABASE IF EXISTS tpch;"
$MYSQL -e "CREATE DATABASE tpch;"

echo "Creating tables..."
$MYSQL tpch < "$SCHEMA_FILE"

for file in "$DATA_DIR"/*.tbl; do
  table=$(basename "$file" .tbl)
  echo "Loading ${table}..."
  $MYSQL --local-infile=1 -e "
    USE tpch;
    LOAD DATA LOCAL INFILE '${DATA_DIR}/${table}.tbl'
    INTO TABLE ${table}
    FIELDS TERMINATED BY '|'
    LINES TERMINATED BY '\n';
  "
done

echo "Verifying..."
$MYSQL -e "
  SELECT 'region' AS tbl, count(*) FROM tpch.region UNION ALL
  SELECT 'nation', count(*) FROM tpch.nation UNION ALL
  SELECT 'supplier', count(*) FROM tpch.supplier UNION ALL
  SELECT 'customer', count(*) FROM tpch.customer UNION ALL
  SELECT 'part', count(*) FROM tpch.part UNION ALL
  SELECT 'partsupp', count(*) FROM tpch.partsupp UNION ALL
  SELECT 'orders', count(*) FROM tpch.orders UNION ALL
  SELECT 'lineitem', count(*) FROM tpch.lineitem
  ORDER BY tbl;
"

echo "TiDB load complete"
