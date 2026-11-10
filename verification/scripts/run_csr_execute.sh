#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/rv64_csr_execute_build}"

mkdir -p "$BUILD_DIR"

"$VERILATOR" \
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
