#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

VERILATOR="${VERILATOR:-/opt/verilator-modern/bin/verilator}"
BUILD_DIR="/tmp/obj_csr_pipeline_90_8d4_v5"

"$VERILATOR" \
    --binary --timing --assert \
    -Wall -Wno-fatal \
    --top-module tb_csr_pipeline_90_8d4 \
    --Mdir "$BUILD_DIR" \
    verification/unit/csr/tb_csr_pipeline_90_8d4.sv \
    rtl/core/pipeline/pipeline_ex_mem.sv \
    rtl/core/pipeline/pipeline_mem_wb.sv

"$BUILD_DIR/Vtb_csr_pipeline_90_8d4"
