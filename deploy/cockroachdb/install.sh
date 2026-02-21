#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"
CRDB_VERSION="v26.1.0"
ARCHITECTURE="linux-amd64"
BASE_IP="10.0.1"
FIRST_NODE_IP="${BASE_IP}.20"
CRDB_TARBALL="/tmp/cockroach-${CRDB_VERSION}.${ARCHITECTURE}.tgz"

echo "Install CockroachDB ${CRDB_VERSION} on ${NODE_COUNT} nodes"

if [ ! -f "$CRDB_TARBALL" ]; then
  echo "Downloading CockroachDB ${CRDB_VERSION} on Controller node..."
  curl -sSL https://binaries.cockroachdb.com/cockroach-${CRDB_VERSION}.${ARCHITECTURE}.tgz -o "$CRDB_TARBALL"
fi

JOIN_LIST=""
for i in $(seq 0 $((NODE_COUNT - 1))); do
  JOIN_LIST="${JOIN_LIST}${BASE_IP}.$((20 + i)):26257,"
done
JOIN_LIST="${JOIN_LIST%,}"

for i in $(seq 0 $((NODE_COUNT - 1))); do
  IP="${BASE_IP}.$((20 + i))"
  echo "Setting up db-node-${i} [${IP}]..."

  echo "  Uploading cockroach tarball to node"
  scp "$CRDB_TARBALL" root@"$IP":/tmp/

  ssh root@"$IP" bash <<REMOTE
    set -e

    if [ ! -f /usr/local/bin/cockroach ]; then
      echo "    [Node] Cockroach not found installing from tarball"
      cd /tmp
      tar xzf cockroach-${CRDB_VERSION}.${ARCHITECTURE}.tgz
      cp cockroach-${CRDB_VERSION}.${ARCHITECTURE}/cockroach /usr/local/bin/
      mkdir -p /usr/local/lib/cockroach
      cp cockroach-${CRDB_VERSION}.${ARCHITECTURE}/lib/* /usr/local/lib/cockroach/ 2>/dev/null || true
      rm -rf cockroach-${CRDB_VERSION}.${ARCHITECTURE}*
    fi

      mkdir -p /var/lib/cockroach

      cat > /etc/systemd/system/cockroach.service <<EOF
[Unit]
Description=Cockroach Database cluster node
Requires=network.target
[Service]
Type=notify
WorkingDirectory=/var/lib/cockroach
ExecStart=/usr/local/bin/cockroach start \\
  --insecure \\
  --advertise-addr=${IP} \\
  --join=${JOIN_LIST} \\
  --store=/var/lib/cockroach \\
  --listen-addr=0.0.0.0:26257 \\
  --http-addr=0.0.0.0:8080 \\
  --cache=.25 \\
  --max-sql-memory=.25
TimeoutStopSec=300
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable cockroach
    systemctl start cockroach
REMOTE
done

echo "Waiting for nodes..."
for i in $(seq 0 $((NODE_COUNT - 1))); do
  IP="${BASE_IP}.$((20 + i))"
  echo -n "  Waiting for db-node-${i}..."
  until ssh root@"$IP" "ss -tlnp | grep -q 26257"; do
    echo -n "."
    sleep 5
  done
  echo " ready"
done

echo "Initializing cluster..."
ssh root@"$FIRST_NODE_IP" \
  "cockroach init --insecure --host=${FIRST_NODE_IP}:26257" 2>/dev/null || echo "Already initialized"

echo "Waiting for cluster to stabilize..."
sleep 5

echo ""
ssh root@"$FIRST_NODE_IP" \
  "cockroach node status --insecure --host=${FIRST_NODE_IP}:26257"
echo ""
echo "CockroachDB ready at ${FIRST_NODE_IP}:26257"
