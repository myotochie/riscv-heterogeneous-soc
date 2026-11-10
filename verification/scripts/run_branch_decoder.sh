#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"

cd "$(dirname "$0")/../.."

"$VERILATOR" --cc --exe --build --sv \
    --top-module decoder \
    --Mdir "${BUILD_DIR:-obj_dir/branch_decoder}" \
    rtl/core/core_pkg.sv \
    rtl/core/decoder/decoder.sv \
    "$(pwd)/verification/unit/decoder/tb_branch_decoder.cpp"

"${BUILD_DIR:-obj_dir/branch_decoder}/Vdecoder"
