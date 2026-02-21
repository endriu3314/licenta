#!/bin/bash
set -euo pipefail

NODE_COUNT=${1}
SCALE_FACTOR=${2}
BASE_IP="10.0.1"
FIRST_NODE_IP="${BASE_IP}.20"
DATA_DIR="/root/benchmark/data/tpch/sf$SCALE_FACTOR"
SCHEMA_FILE="/root/benchmark/schemas/tpch/citus/create_tables.sql"
DISTRIBUTE_FILE="/root/benchmark/schemas/tpch/citus/distribute_tables.sql"

echo "Loading TPC-H into Citus"

echo "Copying data to db-node-0..."
for file in "$DATA_DIR"/*.tbl; do
  table=$(basename "$file" .tbl)
  scp "$file" root@"$FIRST_NODE_IP":/tmp/"${table}.tbl"
done

ssh root@"$FIRST_NODE_IP" bash <<REMOTE
  set -e
  PSQL="sudo -u postgres psql"

  \$PSQL -c "SELECT * FROM citus_get_active_worker_nodes();"

  echo "Creating tables..."
  \$PSQL -c "$(cat "$SCHEMA_FILE")"

  echo "Distributing tables..."
  \$PSQL -c "$(cat "$DISTRIBUTE_FILE")"

  TABLES=(region nation supplier customer part partsupp orders lineitem)
  for table in "\${TABLES[@]}"; do
    echo "  Loading \${table}..."
    \$PSQL -c "\\COPY \${table} FROM '/tmp/\${table}.tbl' WITH (FORMAT csv, DELIMITER '|');"
  done

  echo "Analyzing..."
  for table in "\${TABLES[@]}"; do
    \$PSQL -c "ANALYZE \${table};"
  done

  echo "Verifying..."
  \$PSQL -c "
    SELECT 'region' AS tbl, count(*) FROM region UNION ALL
    SELECT 'nation', count(*) FROM nation UNION ALL
    SELECT 'supplier', count(*) FROM supplier UNION ALL
    SELECT 'customer', count(*) FROM customer UNION ALL
    SELECT 'part', count(*) FROM part UNION ALL
    SELECT 'partsupp', count(*) FROM partsupp UNION ALL
    SELECT 'orders', count(*) FROM orders UNION ALL
    SELECT 'lineitem', count(*) FROM lineitem
    ORDER BY tbl;
  "

  \$PSQL -c "SELECT * FROM citus_tables ORDER BY table_name;"
REMOTE

echo "Citus load complete"
