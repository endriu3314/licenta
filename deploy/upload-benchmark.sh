#!/bin/bash
set -euo pipefail

CONTROLLER_IP="${1}"
SCALE_FACTOR="${2}"
NODE_COUNT="${3}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Uploading benchmark to controller ($CONTROLLER_IP)"

echo "Making dirs..."
ssh root@"$CONTROLLER_IP" \
  "mkdir -p /root/benchmark/{queries,results,schemas,deploy}"

echo "Uploading JAR..."
scp "$PROJECT_DIR/benchmark/target/benchmark-1.jar" root@"$CONTROLLER_IP":/root/benchmark

echo "Uploading queries..."
scp -r "$PROJECT_DIR/queries/tpch" root@"$CONTROLLER_IP":/root/benchmark/queries

echo "Uploading schemas..."
scp -r "$PROJECT_DIR/schemas/tpch" root@"$CONTROLLER_IP":/root/benchmark/schemas/

echo "Uploading deploy scripts..."
scp -r "$PROJECT_DIR/deploy/"* root@"$CONTROLLER_IP":/root/benchmark/deploy/
ssh root@"$CONTROLLER_IP" "chmod +x /root/benchmark/deploy/**/*.sh"

echo "Uploading .env..."
scp "$PROJECT_DIR/.env.prod" root@"$CONTROLLER_IP":/root/benchmark/.env

echo "Uploading generate script..."
scp "$PROJECT_DIR/generate-tpch.sh" root@"$CONTROLLER_IP":/root/benchmark/

echo "Installing dependencies on controller..."
ssh root@"$CONTROLLER_IP" bash <<'REMOTE'
  apt-get update -qq
  apt-get install -y -qq openjdk-25-jre-headless gcc make git mysql-client
REMOTE

echo "Generating TPC-H SF${SCALE_FACTOR} data on controller..."
ssh root@"$CONTROLLER_IP" \
  "cd /root/benchmark && chmod +x generate-tpch.sh && ./generate-tpch.sh ${SCALE_FACTOR}"

echo "Setting up SSH from controller to DB nodes..."
ssh root@"$CONTROLLER_IP" bash <<'REMOTE'
  if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
  fi
REMOTE
CONTROLLER_PUB=$(ssh root@"$CONTROLLER_IP" "cat /root/.ssh/id_rsa.pub")

echo "Distributing controller SSH key to DB nodes..."
for i in $(seq 0 $((NODE_COUNT - 1))); do
  IP="10.0.1.$((20 + i))"
  ssh root@"$CONTROLLER_IP" "ssh-keyscan -H $IP >> ~/.ssh/known_hosts"
  ssh -J root@"$CONTROLLER_IP" root@"$IP" "echo '$CONTROLLER_PUB' >> ~/.ssh/authorized_keys"
done

echo "Upload complete"