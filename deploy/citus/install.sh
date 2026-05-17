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
    CONF_D="/etc/postgresql/${PG_VERSION}/main/conf.d"
    mkdir -p "\$CONF_D"

    sed -i "s/^#\\?listen_addresses.*/listen_addresses = '*'/" "\$PG_CONF"
    grep -q "citus" "\$PG_CONF" || echo "shared_preload_libraries = 'citus'" >> "\$PG_CONF"
    grep -q "shared_buffers = 6GB" "\$PG_CONF" || cat >> "\$PG_CONF" <<PGEOF
shared_buffers = 6GB
work_mem = 32MB
hash_mem_multiplier = 1.0
max_connections = 200
maintenance_work_mem = 512MB

enable_hashagg = on

effective_cache_size = 18GB
PGEOF

    grep -q "10.0.0.0/16" "\$PG_HBA" || cat >> "\$PG_HBA" <<PGEOF
host all all 10.0.0.0/16 trust
PGEOF

    sysctl -w vm.overcommit_memory=2
    sysctl -w vm.overcommit_ratio=80
    grep -q "vm.overcommit_memory" /etc/sysctl.conf || \
      echo -e "\nvm.overcommit_memory=2\nvm.overcommit_ratio=80" >> /etc/sysctl.conf

    mkdir -p /etc/systemd/system/postgresql.service.d
    cat > /etc/systemd/system/postgresql.service.d/oom-protect.conf <<SVCEOF
[Service]
OOMScoreAdjust=-900
SVCEOF
    systemctl daemon-reload

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
  sudo -u postgres psql -c "ALTER SYSTEM SET citus.max_intermediate_result_size = 4194304;"
  sudo -u postgres psql -c "SELECT pg_reload_conf();"
REMOTE

echo ""
ssh root@"$FIRST_NODE_IP" \
  "sudo -u postgres psql -c \"SELECT * FROM citus_get_active_worker_nodes();\""
echo ""
echo "Citus ready at ${FIRST_NODE_IP}:5432"
