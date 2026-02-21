#!/bin/bash
set -euo pipefail

NODE_COUNT="${1}"
TIDB_VERSION="v8.5.5"
BASE_IP="10.0.1"

export PATH="$HOME/.tiup/bin:$PATH"
if ! command -v tiup &>/dev/null; then
    echo "TiUP not found on controller node, installing..."
    curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
fi
export PATH="$HOME/.tiup/bin:$PATH"

which tiup

tiup update --self
tiup install cluster

# Role allocation
if [ "$NODE_COUNT" -le 5 ]; then
  # Co-located: all components share nodes
  PD_COUNT=$(( NODE_COUNT < 3 ? NODE_COUNT : 3 ))
  PD_NODES=$(seq 0 $((PD_COUNT - 1)))
  TIKV_NODES=$(seq 0 $((NODE_COUNT - 1)))
  TIDB_NODES="0"
else
  # Dedicated: PD+TiDB on first 3, TiKV on the rest
  PD_COUNT=3
  PD_NODES=$(seq 0 2)
  TIDB_NODES=$(seq 0 2)
  TIKV_NODES=$(seq 3 $((NODE_COUNT - 1)))
fi

TIKV_COUNT=$(echo $TIKV_NODES | wc -w | tr -d ' ')
TIDB_COUNT=$(echo $TIDB_NODES | wc -w | tr -d ' ')

generate_hosts() {
  for i in $1; do
    echo "  - host: ${BASE_IP}.$((20 + i))"
  done
}

TOPO="/tmp/tidb-topology.yaml"

rm -f $TOPO
touch $TOPO
cat > "$TOPO" <<EOF
global:
  user: "root"
  ssh_port: 22
  deploy_dir: "/tidb-deploy"
  data_dir: "/tidb-data"

pd_servers:
$(generate_hosts "$PD_NODES")

tikv_servers:
$(generate_hosts "$TIKV_NODES")

tidb_servers:
$(generate_hosts "$TIDB_NODES")

monitoring_servers:
  - host: ${BASE_IP}.20

grafana_servers:
  - host: ${BASE_IP}.20
EOF

echo "Topology (${NODE_COUNT} nodes: ${PD_COUNT} PD, ${TIKV_COUNT} TiKV, ${TIDB_COUNT} TiDB):"
cat "$TOPO"
echo ""


tiup cluster deploy tpch-cluster "$TIDB_VERSION" "$TOPO" --yes
tiup cluster start tpch-cluster

echo ""
tiup cluster display tpch-cluster
echo ""
echo "TiDB ready at ${BASE_IP}.20:4000"
