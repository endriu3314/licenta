#!/bin/bash
set -euo pipefail

echo "Tearing down TiDB"

export PATH="$HOME/.tiup/bin:$PATH"
if ! command -v tiup &>/dev/null; then
    echo "TiUP not found on controller node, installing..."
    curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
fi
export PATH="$HOME/.tiup/bin:$PATH"

tiup cluster stop tpch-cluster --yes 2>/dev/null || true
tiup cluster destroy tpch-cluster --yes 2>/dev/null || true
