#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-/tmp/rv64_cf03_unit}"
mkdir -p "$BUILD_ROOT"
run() {
    local name="$1"; shift
    local build="$BUILD_ROOT/$name"
    "$VERILATOR" --cc --exe --build --sv --top-module "$name" --Mdir "$build" "$@"
    "$build/V$name"
}
run decoder rtl/core/core_pkg.sv rtl/core/decoder/decoder.sv "$PWD/verification/unit/decoder/tb_jump_decoder.cpp"
run branch_target rtl/core/control/branch_target.sv "$PWD/verification/unit/branch_target/tb_branch_target.cpp"
run execute_stage "-GENABLE_FORWARDING=1'b1" rtl/core/core_pkg.sv rtl/core/alu/alu.sv \
    rtl/core/hazard/forwarding_mux.sv rtl/core/execute/execute_stage.sv \
    "$PWD/verification/unit/execute_stage/tb_jump_execute.cpp"
