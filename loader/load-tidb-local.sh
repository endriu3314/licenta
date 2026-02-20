#!/bin/bash

set -e

NETWORK="tidb_default"
DATA_FOLDER="../data/tpch/sf0.01"
SCHEMA_FILE="../schemas/tpch/tidb/create_tables.sql"

MYSQL="docker run --rm --network $NETWORK mysql:8 mysql -h tidb -P 4000 -u root"

echo "Loading TPC-H into TiDB"
echo ""

echo "Creating database tpch"
$MYSQL -e "CREATE DATABASE IF NOT EXISTS tpch;"
echo ""

echo "Creating tables"
SQL_CONTENT=$(cat $SCHEMA_FILE)
$MYSQL --database=tpch -e "$SQL_CONTENT"
echo ""

for file in "$DATA_FOLDER"/*.tbl; do
  table_name=$(basename "$file" .tbl)
  echo "Loading $file into table $table_name..."
  docker run --rm --network $NETWORK \
    -v "$(realpath "$file"):/tmp/$table_name.tbl" \
    mysql:8 mysql -h tidb -P 4000 -u root --local-infile=1 tpch -e "
      LOAD DATA LOCAL INFILE '/tmp/$table_name.tbl'
      INTO TABLE $table_name
      FIELDS TERMINATED BY '|'
      LINES TERMINATED BY '\n';
    "
done

