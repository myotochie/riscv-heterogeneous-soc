
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

run_test pipeline_if_id \
    --top-module pipeline_if_id \
    rtl/core/pipeline/pipeline_if_id.sv \
    verification/unit/pipeline_if_id/tb_pipeline_if_id.cpp

run_test pipeline_id_ex \
    --top-module pipeline_id_ex \
    rtl/core/core_pkg.sv \
    rtl/core/pipeline/pipeline_id_ex.sv \
    verification/unit/pipeline_id_ex/tb_pipeline_id_ex.cpp

run_test pipeline_ex_mem \
    --top-module pipeline_ex_mem \
    rtl/core/pipeline/pipeline_ex_mem.sv \
    verification/unit/pipeline_ex_mem/tb_pipeline_ex_mem.cpp

run_test pipeline_mem_wb \
    --top-module pipeline_mem_wb \
    rtl/core/pipeline/pipeline_mem_wb.sv \
    verification/unit/pipeline_mem_wb/tb_pipeline_mem_wb.cpp

run_test fetch_path \
    --top-module fetch_path \
    rtl/core/pc/pc.sv \
    rtl/core/pipeline/pipeline_if_id.sv \
    rtl/core/pipeline/fetch_path.sv \
    verification/integration/tb_fetch_path.cpp

run_test decode_stage \
    --top-module decode_stage \
    rtl/core/core_pkg.sv \
    rtl/core/decoder/decoder.sv \
    rtl/core/imm_gen/imm_gen.sv \
    rtl/core/regfile/regfile.sv \
    rtl/core/decode/decode_stage.sv \
    verification/unit/decode_stage/tb_decode_stage.cpp

run_test fetch_decode_path \
    --top-module fetch_decode_path \
    rtl/core/core_pkg.sv \
    rtl/core/pc/pc.sv \
    rtl/core/pipeline/pipeline_if_id.sv \
    rtl/core/pipeline/fetch_path.sv \
    rtl/core/decoder/decoder.sv \
    rtl/core/imm_gen/imm_gen.sv \
    rtl/core/regfile/regfile.sv \
    rtl/core/decode/decode_stage.sv \
    rtl/core/pipeline/pipeline_id_ex.sv \
    rtl/core/pipeline/fetch_decode_path.sv \
    verification/integration/tb_fetch_decode_path.cpp

run_test execute_stage \
    --top-module execute_stage \
    rtl/core/core_pkg.sv \
    rtl/core/alu/alu.sv \
    rtl/core/hazard/forwarding_unit.sv \
    rtl/core/hazard/forwarding_mux.sv \
    rtl/core/execute/execute_stage.sv \
    verification/unit/execute_stage/tb_execute_stage.cpp

run_test fetch_decode_execute_path \
    --top-module fetch_decode_execute_path \
    rtl/core/core_pkg.sv \
    rtl/core/pc/pc.sv \
    rtl/core/pipeline/pipeline_if_id.sv \
    rtl/core/pipeline/fetch_path.sv \
    rtl/core/decoder/decoder.sv \
    rtl/core/imm_gen/imm_gen.sv \
    rtl/core/regfile/regfile.sv \
    rtl/core/decode/decode_stage.sv \
    rtl/core/pipeline/pipeline_id_ex.sv \
    rtl/core/pipeline/fetch_decode_path.sv \
    rtl/core/alu/alu.sv \
    rtl/core/hazard/forwarding_unit.sv \
    rtl/core/hazard/forwarding_mux.sv \
    rtl/core/execute/execute_stage.sv \
    rtl/core/pipeline/pipeline_ex_mem.sv \
    rtl/core/pipeline/fetch_decode_execute_path.sv \
    verification/integration/tb_fetch_decode_execute_path.cpp

run_test writeback_stage \
    --top-module writeback_stage \
    rtl/core/writeback/writeback_stage.sv \
    verification/unit/writeback_stage/tb_writeback_stage.cpp

run_test rv64_pipeline \
    --top-module rv64_pipeline \
    rtl/core/core_pkg.sv \
    rtl/core/pc/pc.sv \
    rtl/core/pipeline/pipeline_if_id.sv \
    rtl/core/pipeline/fetch_path.sv \
    rtl/core/decoder/decoder.sv \
    rtl/core/imm_gen/imm_gen.sv \
    rtl/core/regfile/regfile.sv \
    rtl/core/decode/decode_stage.sv \
    rtl/core/pipeline/pipeline_id_ex.sv \
    rtl/core/pipeline/fetch_decode_path.sv \
    rtl/core/alu/alu.sv \
    rtl/core/hazard/forwarding_unit.sv \
    rtl/core/hazard/forwarding_mux.sv \
    rtl/core/execute/execute_stage.sv \
    rtl/core/pipeline/pipeline_ex_mem.sv \
    rtl/core/pipeline/fetch_decode_execute_path.sv \
    rtl/core/pipeline/pipeline_mem_wb.sv \
    rtl/core/writeback/writeback_stage.sv \
    rtl/core/pipeline/rv64_pipeline.sv \
    verification/integration/tb_rv64_regfile.cpp
echo
echo ">>> Building and testing: rv64_raw_forwarding"
verilator --cc --exe --build --sv \
    --top-module rv64_pipeline \
    "-GRAW_TEST_PROGRAM=1'b1" \
    --Mdir obj_dir/rv64_raw \
    rtl/core/core_pkg.sv \
    rtl/core/pc/pc.sv \
    rtl/core/pipeline/pipeline_if_id.sv \
    rtl/core/pipeline/fetch_path.sv \
    rtl/core/decoder/decoder.sv \
    rtl/core/imm_gen/imm_gen.sv \
    rtl/core/regfile/regfile.sv \
    rtl/core/decode/decode_stage.sv \
    rtl/core/pipeline/pipeline_id_ex.sv \
    rtl/core/pipeline/fetch_decode_path.sv \
    rtl/core/alu/alu.sv \
    rtl/core/hazard/forwarding_unit.sv \
    rtl/core/hazard/forwarding_mux.sv \
    rtl/core/execute/execute_stage.sv \
    rtl/core/pipeline/pipeline_ex_mem.sv \
    rtl/core/pipeline/fetch_decode_execute_path.sv \
    rtl/core/pipeline/pipeline_mem_wb.sv \
    rtl/core/writeback/writeback_stage.sv \
    rtl/core/pipeline/rv64_pipeline.sv \
    "$(pwd)/verification/integration/tb_rv64_raw_forwarding.cpp"

./obj_dir/rv64_raw/Vrv64_pipeline
echo ">>> rv64_raw_forwarding: PASS"

echo
echo "======================================"
echo " ALL TEST SUITES PASSED"
echo "======================================"
