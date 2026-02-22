#!/bin/bash

set -e

DATA_FOLDER="../data/tpch/sf0.01"
SCHEMA_FILE="../schemas/tpch/citus/create_tables.sql"
DISTRIBUTE_FILE="../schemas/tpch/citus/distribute_tables.sql"
PSQL="docker exec citus_coordinator psql -U postgres"

echo "Loading TPC-H into Citus"
echo ""

echo "Active workers:"
$PSQL -c "SELECT * FROM citus_get_active_worker_nodes();"
echo ""

echo "Creating tables..."
SQL_CONTENT=$(cat "$SCHEMA_FILE")
$PSQL -c "$SQL_CONTENT"
echo ""

echo "Distributing tables..."
SQL_CONTENT=$(cat "$DISTRIBUTE_FILE")
$PSQL -c "$SQL_CONTENT"
echo ""

for file in "$DATA_FOLDER"/*.tbl; do
  table_name=$(basename "$file" .tbl)
  file="$DATA_FOLDER/${table_name}.tbl"
  echo "Loading $table_name..."
  docker cp "$file" citus_coordinator:/tmp/"${table_name}.tbl"
  $PSQL -c "\COPY ${table_name} FROM '/tmp/${table_name}.tbl' WITH (FORMAT csv, DELIMITER '|');"
done
echo ""

for file in "$DATA_FOLDER"/*.tbl; do
  table_name=$(basename "$file" .tbl)
  $PSQL -c "ANALYZE ${table_name};"
done

echo "Enabling repartition joins..."
$PSQL -c "ALTER SYSTEM SET citus.task_executor_type = 'adaptive';"
$PSQL -c "ALTER SYSTEM SET citus.enable_repartition_joins = on;"
$PSQL -c "ALTER SYSTEM SET citus.multi_shard_modify_mode = 'sequential';"
$PSQL -c "SELECT pg_reload_conf();"

echo "Verifying..."
$PSQL -c "
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

$PSQL -c "SELECT * FROM citus_tables ORDER BY table_name;"
