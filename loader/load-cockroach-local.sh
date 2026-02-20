#!/bin/bash

set -e

CRDB="docker exec roach1 ./cockroach sql --host=roach1:26257 --insecure"
DATA_FOLDER="../data/tpch/sf1"
SCHEMA_FILE="../schemas/tpch/cockroachdb/create_tables.sql"

echo "Loading TPC-H into CockroachDB"
echo ""

echo "Creating database tpch"
$CRDB -e "CREATE DATABASE IF NOT EXISTS tpch;"
echo ""

echo "Creating tables"
SQL_CONTENT=$(cat $SCHEMA_FILE)
$CRDB --database=tpch -e "$SQL_CONTENT"
echo ""

for file in "$DATA_FOLDER"/*.tbl; do
  table_name=$(basename "$file" .tbl)
  echo "Loading $file into table $table_name..."
    docker cp "$file" roach1:/tmp/"$table_name.tbl"
    docker exec roach1 ./cockroach nodelocal upload \
      /tmp/"$table_name".tbl \
      "$table_name".tbl \
      --host=roach1:26257 \
      --insecure

    $CRDB --database=tpch -e "
      IMPORT INTO $table_name
      CSV DATA ('nodelocal://1/$table_name.tbl')
      WITH delimiter = '|', nullif = '';
    "
done
