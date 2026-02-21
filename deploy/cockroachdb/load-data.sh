#!/bin/bash
set -euo pipefail

NODE_COUNT=${1}
SCALE_FACTOR=${2}
BASE_IP="10.0.1"
FIRST_NODE_IP="${BASE_IP}.20"
CONTROLLER_IP="${BASE_IP}.10"  # adjust to your controller's private IP
DATA_DIR="/root/benchmark/data/tpch/sf$SCALE_FACTOR"
SCHEMA_FILE="/root/benchmark/schemas/tpch/cockroachdb/create_tables.sql"
NGINX_PORT=8080
SOURCE_URL="http://${CONTROLLER_IP}:${NGINX_PORT}/tpch"
SPLIT_THRESHOLD_MB=500
SPLIT_CHUNK_SIZE="2G"

echo "Loading TPC-H SF${SCALE_FACTOR} into CockroachDB"

TABLES=(region nation supplier part customer partsupp orders lineitem)

crdb_sql() {
    ssh root@"$FIRST_NODE_IP" "cockroach sql --insecure --host=localhost:26257 $*"
}

echo "========================"
echo "Prepairing data files..."
echo "========================"
for table in "${TABLES[@]}"; do
  file="$DATA_DIR/${table}.tbl"
  size_mb=$(( $(stat -c%s "$file") / 1024 / 1024 ))

  if (( size_mb > SPLIT_THRESHOLD_MB )); then
    echo "  [ SPLIT ] $file is ${size_mb}MB"
    parts_dir="$DATA_DIR/${table}_parts"
    if [ ! "$(ls -A "$parts_dir" 2>/dev/null)" ]; then
      echo "    ${table} is ${size_mb}MB — splitting into ~${SPLIT_CHUNK_SIZE} chunks..."
      mkdir -p "$parts_dir"
      split -C "$SPLIT_CHUNK_SIZE" "$file" "$parts_dir/${table}_"
      for f in "$parts_dir"/${table}_*; do
        [[ "$f" != *.tbl ]] && mv "$f" "${f}.tbl"
      done
      echo "    ${table}: $(ls "$parts_dir"/*.tbl | wc -l) parts"
    else
      echo "    ${table} already split"
    fi
  else
    echo "  [NOSPLIT] $file is ${size_mb}MB"
  fi
done

echo "========================"
echo "Setting up nginx..."
echo "========================"
sudo tee /etc/nginx/sites-available/tpch > /dev/null <<EOF
server {
    listen ${NGINX_PORT};
    location /tpch/ {
        alias ${DATA_DIR}/;
        autoindex on;
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
    }
}
EOF

chmod 755 /root /root/benchmark /root/benchmark/data /root/benchmark/data/tpch
chown -R www-data:www-data "$DATA_DIR"

sudo ln -sf /etc/nginx/sites-available/tpch /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

if ! ssh root@"$FIRST_NODE_IP" "curl -sf ${SOURCE_URL}/region.tbl > /dev/null"; then
    echo "ERROR: CRDB nodes cannot reach ${SOURCE_URL}"
    exit 1
fi
echo "nginx ready"

echo "========================"
echo "Setting up database..."
echo "========================"
crdb_sql -e "\"DROP DATABASE IF EXISTS tpch CASCADE;\""
crdb_sql -e "\"CREATE DATABASE tpch;\""
crdb_sql --database=tpch -e "\"$(cat "$SCHEMA_FILE")\""

# echo "========================"
# echo "Tune for bulk import..."
# echo "========================"
# crdb_sql -e "\"
#   SET CLUSTER SETTING sql.stats.automatic_collection.enabled = false;
#   SET CLUSTER SETTING kv.bulk_io_write.concurrent_addsstable_requests = 16;
#   SET CLUSTER SETTING kv.bulk_io_write.max_rate = '0';
# \""

echo "========================"
echo "Importing tables..."
echo "========================"
for table in "${TABLES[@]}"; do
    file="$DATA_DIR/${table}.tbl"
    size_mb=$(( $(stat -c%s "$file") / 1024 / 1024 ))
    parts_dir="$DATA_DIR/${table}_parts"
    start=$(date +%s)

    echo "$file"

    if [[ -d "$parts_dir" ]] && (( size_mb > SPLIT_THRESHOLD_MB )); then
      count=$(ls "$parts_dir"/*.tbl | wc -l)
      echo "  ${table} (${size_mb}MB, ${count} parts)..."

      files=""
      for f in "$parts_dir"/*.tbl; do
          files+="'${SOURCE_URL}/${table}_parts/$(basename "$f")',"
          echo "    ${SOURCE_URL}/${table}_parts/$(basename "$f")"
      done
      files="${files%,}"

      crdb_sql --database=tpch -e "\"
        IMPORT INTO ${table}
        CSV DATA (${files})
        WITH delimiter = '|', nullif = '';
      \""
    else
      echo "  ${table} (${size_mb}MB, single file)..."
      crdb_sql --database=tpch -e "\"
        IMPORT INTO ${table}
        CSV DATA ('${SOURCE_URL}/${table}.tbl')
        WITH delimiter = '|', nullif = '';
      \""
    fi

    echo "  ${table} done in $(( $(date +%s) - start ))s"
done

echo "========================"
echo "Post-import..."
echo "========================"
# crdb_sql -e "\"
#   SET CLUSTER SETTING sql.stats.automatic_collection.enabled = true;
#   SET CLUSTER SETTING kv.bulk_io_write.concurrent_addsstable_requests = 1;
# \""

for table in "${TABLES[@]}"; do
    crdb_sql --database=tpch -e "\"ANALYZE tpch.${table};\"" &
done

sudo systemctl stop nginx


echo "========================"
echo "Row counts..."
echo "========================"
crdb_sql --database=tpch -e "\"
    SELECT 'region' AS tbl, count(*) FROM tpch.region UNION ALL
    SELECT 'nation', count(*) FROM tpch.nation UNION ALL
    SELECT 'supplier', count(*) FROM tpch.supplier UNION ALL
    SELECT 'customer', count(*) FROM tpch.customer UNION ALL
    SELECT 'part', count(*) FROM tpch.part UNION ALL
    SELECT 'partsupp', count(*) FROM tpch.partsupp UNION ALL
    SELECT 'orders', count(*) FROM tpch.orders UNION ALL
    SELECT 'lineitem', count(*) FROM tpch.lineitem
    ORDER BY tbl;
\""

echo "CockroachDB TPC-H SF${SCALE_FACTOR} load complete"
