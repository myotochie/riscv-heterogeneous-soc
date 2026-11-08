#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

verilator --cc --exe --build --sv \
    --top-module decoder \
    --Mdir obj_dir/branch_decoder \
    rtl/core/core_pkg.sv \
    rtl/core/decoder/decoder.sv \
    "$(pwd)/verification/unit/decoder/tb_branch_decoder.cpp"

./obj_dir/branch_decoder/Vdecoder
