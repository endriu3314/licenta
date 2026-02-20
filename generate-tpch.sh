#!/bin/bash

set -e

SCALE_FACTOR=1
SEED=10

TPCH_KIT_DIR="$PWD/.tpch-kit"
DBGEN_DIR="$TPCH_KIT_DIR/dbgen"

DATA_DIR="$PWD/data/tpch/sf${SCALE_FACTOR}"
QUERIES_DIR="$PWD/queries/tpch"

# Install kit

if [ -f "$DBGEN_DIR/dbgen" ] && [ -f "$DBGEN_DIR/qgen" ]; then
    echo "tpch-kit already built, skipping"
else
  echo "Cloning tpch-kit..."
  rm -rf "$TPCH_KIT_DIR"
  git clone --depth 1 https://github.com/gregrahn/tpch-kit.git "$TPCH_KIT_DIR"

  echo "Building DBGEN"
  cd "$DBGEN_DIR"
  make clean
  make MACHINE=MACOS DATABASE=POSTGRESQL
fi

# Generate data
cd "$DBGEN_DIR"

if [ -d "$DATA_DIR" ] && ls "$DATA_DIR"/*.tbl &>/dev/null; then
  echo "Data for SF${SCALE_FACTOR} exists, skipping"
else
  echo "Generatic TPC-H data SF${SCALE_FACTOR}..."
  mkdir -p "$DATA_DIR"

  ./dbgen -s "$SCALE_FACTOR" -f
  mv ./*.tbl "$DATA_DIR/"

  echo "SF${SCALE_FACTOR} data generated -> ${DATA_DIR}/"
  ls -lh "$DATA_DIR"/*.tbl | awk '{printf "     %-20s %s\n", $NF, $5}'
fi

# Generate Queries
cd "$DBGEN_DIR"
if ls "$QUERIES_DIR"/q*.sql &>/dev/null; then
  echo "Queries already exists, skipping"
else
  echo "Generating TPC-H queries (seed=${SEED})..."

  ln -sf queries/*.sql . 2>/dev/null

  for i in $(seq 1 22); do
    if ./qgen -s "$SEED" "$i" > "${QUERIES_DIR}/q${i}.sql"; then
      echo "  q${i}.sql"
    else
      echo "  q${i}.sql failed"
    fi
  done
fi
