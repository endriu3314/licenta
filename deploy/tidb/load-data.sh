#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"
SCALE_FACTOR="${2}"
BASE_IP="10.0.1"
FIRST_NODE_IP="${BASE_IP}.20"
DATA_DIR="/root/benchmark/data/tpch/sf$SCALE_FACTOR"
SCHEMA_FILE="/root/benchmark/schemas/tpch/tidb/create_tables.sql"

MINIO_USER="minioadmin"
MINIO_PASS="minioadmin"
CONTROLLER_IP="${BASE_IP}.10"
MINIO_ENDPOINT="http://${CONTROLLER_IP}:9000"
BUCKET="sf${SCALE_FACTOR}"

MYSQL="mysql -h ${FIRST_NODE_IP} -P 4000 -u root"

echo "Loading TPC-H into TiDB"

echo "Updating TiDB settings..."
echo "Updating memory to 4gb"
$MYSQL -e "SET GLOBAL tidb_mem_quota_query = 4 << 30;"


echo "Starting MinIO..."
docker rm -f minio 2>/dev/null || true
docker run -d \
  -p 9000:9000 \
  --name minio \
  -v "/root/benchmark/minio:/data" \
  -e MINIO_ROOT_USER=${MINIO_USER} \
  -e MINIO_ROOT_PASSWORD=${MINIO_PASS} \
  minio/minio server /data

echo "Waiting for MinIO..."
until curl -sf --max-time 2 "http://${CONTROLLER_IP}:9000/minio/health/live" > /dev/null 2>&1; do
  echo "  waiting..."
  sleep 2
done

echo "Creating bucket..."
docker run --rm --network host \
  -e MC_HOST_local="http://${MINIO_USER}:${MINIO_PASS}@${CONTROLLER_IP}:9000" \
  minio/mc mb --ignore-existing "local/sf${SCALE_FACTOR}"

echo "Uploading TPC-H data into bucket..."
docker run --rm --network host \
  -v "/root/benchmark/data/tpch/sf${SCALE_FACTOR}:/tpch-data" \
  -e MC_HOST_local="http://${MINIO_USER}:${MINIO_PASS}@${CONTROLLER_IP}:9000" \
  minio/mc mirror /tpch-data "local/sf${SCALE_FACTOR}"

echo "Verifying contents..."
docker run --rm --network host \
  -e MC_HOST_local="http://${MINIO_USER}:${MINIO_PASS}@${CONTROLLER_IP}:9000" \
  minio/mc ls "local/sf${SCALE_FACTOR}"

echo "Checking MinIO reachability from TiDB node..."
ssh root@${FIRST_NODE_IP} "curl -sf --max-time 5 ${MINIO_ENDPOINT}/minio/health/ready" \
  && echo "  TiDB node can reach MinIO." \
  || { echo "ERROR: TiDB node cannot reach MinIO at ${MINIO_ENDPOINT}. Check firewall/network."; exit 1; }

echo "Creating database..."
$MYSQL -e "DROP DATABASE IF EXISTS tpch;"
$MYSQL -e "CREATE DATABASE tpch;"

echo "Creating tables..."
$MYSQL tpch < "$SCHEMA_FILE"

S3_BASE="s3://${BUCKET}"
S3_PARAMS="access-key=${MINIO_USER}&secret-access-key=${MINIO_PASS}&endpoint=${MINIO_ENDPOINT}&force-path-style=true"

for file in "$DATA_DIR"/*.tbl; do
  table=$(basename "$file" .tbl)
  echo "Loading ${table}..."

  job_id=$($MYSQL tpch --skip-column-names -e "
    IMPORT INTO ${table}
    FROM '${S3_BASE}/${table}.tbl?${S3_PARAMS}'
    FORMAT 'CSV'
    WITH
      fields_terminated_by='|',
      lines_terminated_by='\n',
      detached;
  " | awk '{print $1}')

  echo "  Job ID: ${job_id} — waiting for completion..."
  while true; do
    status=$($MYSQL -e "SHOW IMPORT JOB ${job_id};" | awk 'NR==2{print $5}')
    echo "  Status: ${status}"
    [[ "$status" == "finished" ]] && break
    [[ "$status" == "failed" ]] && { echo "ERROR: Import failed for ${table}"; exit 1; }
    sleep 5
  done

  echo "  ${table} done."
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

docker stop minio
docker rm minio

echo "TiDB load complete"
