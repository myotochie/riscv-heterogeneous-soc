#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="/tmp/rv64_csr_trap_priority"

if [[ -x /opt/verilator-modern/bin/verilator ]]; then
    VERILATOR=/opt/verilator-modern/bin/verilator
else
    VERILATOR="$(command -v verilator)"
fi

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
