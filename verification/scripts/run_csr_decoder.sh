#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="/tmp/rv64_csr_decoder_build"

echo "======================================"
echo " RV64 CSR DECODER UNIT TEST"
echo "======================================"

for file in \
    "$ROOT/rtl/core/core_pkg.sv" \
    "$ROOT/rtl/core/decoder/decoder.sv" \
    "$ROOT/verification/unit/csr/tb_csr_decoder.cpp"
do
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] Missing file: $file" >&2
        exit 1
    fi
done

rm -rf "$BUILD_DIR"

verilator \
    --cc --exe --build --sv \
    --top-module decoder \
    -Wno-fatal \
    --Mdir "$BUILD_DIR" \
    "$ROOT/rtl/core/core_pkg.sv" \
    "$ROOT/rtl/core/decoder/decoder.sv" \
    "$ROOT/verification/unit/csr/tb_csr_decoder.cpp"

echo
echo "======================================"
echo " RUNNING CSR DECODER TESTS"
echo "======================================"

"$BUILD_DIR/Vdecoder"
