#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="/tmp/rv64_csr_execute_build"

rm -rf "$BUILD_DIR"

verilator \
    --cc \
    --exe \
    --build \
    --sv \
    --top-module csr_execute \
    -Wno-fatal \
    --Mdir "$BUILD_DIR" \
    "$ROOT/rtl/core/csr/csr_execute.sv" \
    "$ROOT/verification/unit/csr/tb_csr_execute.cpp"

"$BUILD_DIR/Vcsr_execute"
