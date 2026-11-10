#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${BUILD_DIR:-/tmp/rv64_csr_trap_priority}"


mkdir -p "$BUILD"
cd "$ROOT"

"$VERILATOR" \
    --cc \
    --exe \
    --build \
    -Wno-fatal \
    --top-module csr_file \
    --Mdir "$BUILD" \
    rtl/core/csr/csr_file.sv \
    verification/unit/rv64_pipeline/tb_csr_trap_priority.cpp \
    > "$BUILD/build.log" 2>&1 || {
        echo "[FAIL] Compilation"
        tail -n 60 "$BUILD/build.log"
        exit 1
    }

echo "===== CSR / TRAP PRIORITY TEST ====="
"$BUILD/Vcsr_file"
