#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"
BASE_IP="10.0.1"
PG_VERSION="17"
CITUS_VERSION="13.0"
FIRST_NODE_IP="${BASE_IP}.20"

echo "Installing Citus on ${NODE_COUNT} nodes"

for i in $(seq 0 $((NODE_COUNT - 1))); do
  IP="${BASE_IP}.$((20 + i))"
  ROLE=$( [ "$i" -eq 0 ] && echo "coordinator" || echo "worker-${i}" )
  echo "Setting up ${ROLE} (${IP})..."

  ssh -o StrictHostKeyChecking=no root@"$IP" bash <<REMOTE
    set -e

    if ! command -v pg_isready &>/dev/null; then
      curl https://install.citusdata.com/community/deb.sh | bash
      apt-get install -y postgresql-${PG_VERSION}-citus-${CITUS_VERSION}
    fi

    PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
    PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

    sed -i "s/^#\\?listen_addresses.*/listen_addresses = '*'/" "\$PG_CONF"
    grep -q "citus" "\$PG_CONF" || echo "shared_preload_libraries = 'citus'" >> "\$PG_CONF"
    grep -q "shared_buffers = 1GB" "\$PG_CONF" || cat >> "\$PG_CONF" <<PGEOF
shared_buffers = 1GB
work_mem = 64MB
max_connections = 200
PGEOF

    grep -q "10.0.0.0/16" "\$PG_HBA" || cat >> "\$PG_HBA" <<PGEOF
host all all 10.0.0.0/16 trust
PGEOF

    systemctl restart postgresql
    systemctl enable postgresql

    sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS citus;"
REMOTE
done

echo "Waiting for PostgreSQL on all nodes..."
for i in $(seq 0 $((NODE_COUNT - 1))); do
  IP="${BASE_IP}.$((20 + i))"
  echo -n "  db-node-${i} (${IP})..."
  until ssh root@"$IP" "pg_isready -h ${IP} -p 5432" &>/dev/null; do
    echo -n "."
    sleep 3
  done
  echo " ready"
done
echo "Configuring coordinator..."
ssh root@"$FIRST_NODE_IP" bash <<REMOTE
  set -e
  sudo -u postgres psql -c "SELECT citus_set_coordinator_host('${FIRST_NODE_IP}', 5432);"

  for i in \$(seq 1 $((NODE_COUNT - 1))); do
    WORKER_IP="${BASE_IP}.\$((20 + i))"
    echo "  Registering worker \${WORKER_IP}..."
    sudo -u postgres psql -c "SELECT citus_add_node('\${WORKER_IP}', 5432);"
  done

  sudo -u postgres psql -c "ALTER SYSTEM SET citus.enable_repartition_joins = on;"
  sudo -u postgres psql -c "SELECT pg_reload_conf();"
REMOTE

echo ""
ssh root@"$FIRST_NODE_IP" \
  "sudo -u postgres psql -c \"SELECT * FROM citus_get_active_worker_nodes();\""
echo ""
echo "Citus ready at ${FIRST_NODE_IP}:5432"
