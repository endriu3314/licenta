#!/bin/bash
set -euo pipefail

NODE_COUNT=${1}
SCALE_FACTOR=${2}
BASE_IP="10.0.1"
FIRST_NODE_IP="${BASE_IP}.20"
DATA_DIR="/root/benchmark/data/tpch/sf$SCALE_FACTOR"
SCHEMA_FILE="/root/benchmark/schemas/tpch/cockroachdb/create_tables.sql"

echo "Loading TPC-H into CockroachDB"

echo "Copying data to db-node-0..."
for file in "$DATA_DIR"/*.tbl; do
  table=$(basename "$file" .tbl)
  scp "$file" root@"$FIRST_NODE_IP":/tmp/"${table}.tbl"
done

ssh root@"$FIRST_NODE_IP" bash <<REMOTE
  set -e
  CRDB="cockroach sql --insecure --host=localhost:26257"

  echo "Creating database..."
  \$CRDB -e "DROP DATABASE IF EXISTS tpch CASCADE;"
  \$CRDB -e "CREATE DATABASE tpch;"

  echo "Creating tables..."
  \$CRDB --database=tpch -e "$(cat "$SCHEMA_FILE")"

  echo "Loading files..."
  echo "Removing existing files"
  rm -rf /var/lib/cockroach/extern/*

  TABLES=(region nation supplier customer part partsupp orders lineitem)
  for table in "\${TABLES[@]}"; do
    echo "  Loading \${table}..."

    cockroach nodelocal upload \
      /tmp/"\${table}.tbl" \
      "\${table}.tbl" \
      --host=localhost:26257 \
      --insecure

    \$CRDB --database=tpch -e "
      IMPORT INTO \${table}
      CSV DATA ('nodelocal://1/\${table}.tbl')
      WITH delimiter = '|', nullif = '';
    "
  done

  echo "Verifying..."
  \$CRDB --database=tpch -e "
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
REMOTE

echo "CockroachDB load complete"
