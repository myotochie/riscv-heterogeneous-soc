
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "======================================"
echo " RISC-V SoC — Unit Test Regression"
echo "======================================"

run_test() {
    local name="$1"
    shift

    echo
    echo ">>> Building and testing: ${name}"

    verilator --cc --exe --build --sv "$@"
    local executable="./obj_dir/V${name}"

    if [[ ! -x "$executable" ]]; then
        echo "ERROR: executable not found: $executable" >&2
        exit 1
    fi

    "$executable"
    echo ">>> ${name}: PASS"
}

run_test alu \
    --top-module alu \
    rtl/core/core_pkg.sv \
    rtl/core/alu/alu.sv \
    verification/unit/alu/tb_alu.cpp

run_test regfile \
    --top-module regfile \
    rtl/core/regfile/regfile.sv \
    verification/unit/regfile/tb_regfile.cpp

run_test decoder \
    --top-module decoder \
    rtl/core/core_pkg.sv \
    rtl/core/decoder/decoder.sv \
    verification/unit/decoder/tb_decoder.cpp

run_test imm_gen \
    --top-module imm_gen \
    rtl/core/imm_gen/imm_gen.sv \
    verification/unit/imm_gen/tb_imm_gen.cpp

run_test rv64_datapath \
    --top-module rv64_datapath \
    rtl/core/core_pkg.sv \
    rtl/core/alu/alu.sv \
    rtl/core/regfile/regfile.sv \
    rtl/core/decoder/decoder.sv \
    rtl/core/imm_gen/imm_gen.sv \
    rtl/core/rv64_datapath.sv \
    verification/unit/datapath/tb_datapath.cpp

run_test pc \
    --top-module pc \
    rtl/core/pc/pc.sv \
    verification/unit/pc/tb_pc.cpp

run_test branch_target \
    --top-module branch_target \
    rtl/core/control/branch_target.sv \
    verification/unit/branch_target/tb_branch_target.cpp

run_test branch_decision \
    --top-module branch_decision \
    rtl/core/control/branch_decision.sv \
    verification/unit/branch_decision/tb_branch_decision.cpp

run_test control_flow \
    --top-module control_flow \
    rtl/core/control/control_flow.sv \
    verification/unit/control_flow/tb_control_flow.cpp

run_test control_flow_unit \
    --top-module control_flow_unit \
    rtl/core/pc/pc.sv \
    rtl/core/control/branch_target.sv \
    rtl/core/control/branch_decision.sv \
    rtl/core/control/control_flow.sv \
    rtl/core/control/control_flow_unit.sv \
    verification/unit/control_flow_unit/tb_control_flow_unit.cpp

echo
echo "======================================"
echo " ALL TEST SUITES PASSED"
echo "======================================"
