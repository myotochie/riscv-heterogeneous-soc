
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/verilator_env.sh"

cd "$(dirname "$0")/.."
BASE_BUILD_DIR="${BASE_BUILD_DIR:-$PWD/obj_dir}"
mkdir -p "$BASE_BUILD_DIR"

echo "======================================"
echo " RISC-V SoC — Unit Test Regression"
echo "======================================"

run_test() {
    local name="$1"
    shift

    echo
    echo ">>> Building and testing: ${name}"

    "$VERILATOR" --cc --exe --build --sv --Mdir "$BASE_BUILD_DIR" "$@"
    local executable="$BASE_BUILD_DIR/V${name}"

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
    "$PWD/verification/unit/alu/tb_alu.cpp"

run_test regfile \
    --top-module regfile \
    rtl/core/regfile/regfile.sv \
    "$PWD/verification/unit/regfile/tb_regfile.cpp"

run_test decoder \
    --top-module decoder \
    rtl/core/core_pkg.sv \
    rtl/core/decoder/decoder.sv \
    "$PWD/verification/unit/decoder/tb_decoder.cpp"

run_test imm_gen \
    --top-module imm_gen \
    rtl/core/imm_gen/imm_gen.sv \
    "$PWD/verification/unit/imm_gen/tb_imm_gen.cpp"

run_test rv64_datapath \
    --top-module rv64_datapath \
    rtl/core/core_pkg.sv \
    rtl/core/alu/alu.sv \
    rtl/core/regfile/regfile.sv \
    rtl/core/decoder/decoder.sv \
    rtl/core/imm_gen/imm_gen.sv \
    rtl/core/rv64_datapath.sv \
    "$PWD/verification/unit/datapath/tb_datapath.cpp"

run_test pc \
    --top-module pc \
    rtl/core/pc/pc.sv \
    "$PWD/verification/unit/pc/tb_pc.cpp"

run_test branch_target \
    --top-module branch_target \
    rtl/core/control/branch_target.sv \
    "$PWD/verification/unit/branch_target/tb_branch_target.cpp"

run_test branch_decision \
    --top-module branch_decision \
    rtl/core/control/branch_decision.sv \
    "$PWD/verification/unit/branch_decision/tb_branch_decision.cpp"

run_test control_flow \
    --top-module control_flow \
    rtl/core/control/control_flow.sv \
    "$PWD/verification/unit/control_flow/tb_control_flow.cpp"

run_test control_flow_unit \
    --top-module control_flow_unit \
    rtl/core/pc/pc.sv \
    rtl/core/control/branch_target.sv \
    rtl/core/control/branch_decision.sv \
    rtl/core/control/control_flow.sv \
    rtl/core/control/control_flow_unit.sv \
    "$PWD/verification/unit/control_flow_unit/tb_control_flow_unit.cpp"

run_test pipeline_if_id \
    --top-module pipeline_if_id \
    rtl/core/pipeline/pipeline_if_id.sv \
    "$PWD/verification/unit/pipeline_if_id/tb_pipeline_if_id.cpp"

run_test pipeline_id_ex \
    --top-module pipeline_id_ex \
    rtl/core/core_pkg.sv \
    rtl/core/pipeline/pipeline_id_ex.sv \
    "$PWD/verification/unit/pipeline_id_ex/tb_pipeline_id_ex.cpp"

run_test pipeline_ex_mem \
    --top-module pipeline_ex_mem \
    rtl/core/pipeline/pipeline_ex_mem.sv \
    "$PWD/verification/unit/pipeline_ex_mem/tb_pipeline_ex_mem.cpp"

run_test pipeline_mem_wb \
    --top-module pipeline_mem_wb \
    rtl/core/pipeline/pipeline_mem_wb.sv \
    "$PWD/verification/unit/pipeline_mem_wb/tb_pipeline_mem_wb.cpp"

run_test fetch_path \
    --top-module fetch_path \
    rtl/core/pc/pc.sv \
    rtl/core/pipeline/pipeline_if_id.sv \
    rtl/core/pipeline/fetch_path.sv \
    "$PWD/verification/integration/tb_fetch_path.cpp"

run_test decode_stage \
    --top-module decode_stage \
    rtl/core/core_pkg.sv \
    rtl/core/decoder/decoder.sv \
    rtl/core/imm_gen/imm_gen.sv \
    rtl/core/regfile/regfile.sv \
    rtl/core/decode/decode_stage.sv \
    "$PWD/verification/unit/decode_stage/tb_decode_stage.cpp"

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
    "$PWD/verification/integration/tb_fetch_decode_path.cpp"

run_test execute_stage \
    --top-module execute_stage \
    rtl/core/core_pkg.sv \
    rtl/core/alu/alu.sv \
    rtl/core/hazard/forwarding_unit.sv \
    rtl/core/hazard/forwarding_mux.sv \
    rtl/core/execute/execute_stage.sv \
    "$PWD/verification/unit/execute_stage/tb_execute_stage.cpp"

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
    rtl/core/hazard/hazard_detection_unit.sv \
    rtl/core/csr/csr_execute.sv \
    rtl/core/control/branch_decision.sv \
    rtl/core/control/branch_target.sv \
    rtl/core/pipeline/fetch_decode_execute_path.sv \
    "$PWD/verification/integration/tb_fetch_decode_execute_path.cpp"

run_test writeback_stage \
    --top-module writeback_stage \
    rtl/core/writeback/writeback_stage.sv \
    "$PWD/verification/unit/writeback_stage/tb_writeback_stage.cpp"

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
    rtl/core/hazard/hazard_detection_unit.sv \
    rtl/core/csr/csr_execute.sv \
    rtl/core/control/branch_decision.sv \
    rtl/core/control/branch_target.sv \
    rtl/core/pipeline/fetch_decode_execute_path.sv \
    rtl/core/pipeline/pipeline_mem_wb.sv \
    rtl/core/writeback/writeback_stage.sv \
    rtl/core/memory/data_memory.sv \
    rtl/core/csr/csr_file.sv \
    rtl/core/exception/exception_controller.sv \
    rtl/core/pipeline/rv64_pipeline.sv \
    "$PWD/verification/integration/tb_rv64_regfile.cpp"
echo
echo ">>> Building and testing: rv64_raw_forwarding"
"$VERILATOR" --cc --exe --build --sv \
    --top-module rv64_pipeline \
    "-GRAW_TEST_PROGRAM=1'b1" \
    --Mdir "$BASE_BUILD_DIR/rv64_raw" \
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
    rtl/core/hazard/hazard_detection_unit.sv \
    rtl/core/csr/csr_execute.sv \
    rtl/core/control/branch_decision.sv \
    rtl/core/control/branch_target.sv \
    rtl/core/pipeline/fetch_decode_execute_path.sv \
    rtl/core/pipeline/pipeline_mem_wb.sv \
    rtl/core/writeback/writeback_stage.sv \
    rtl/core/memory/data_memory.sv \
    rtl/core/csr/csr_file.sv \
    rtl/core/exception/exception_controller.sv \
    rtl/core/pipeline/rv64_pipeline.sv \
    "$(pwd)/verification/integration/tb_rv64_raw_forwarding.cpp"

"$BASE_BUILD_DIR/rv64_raw/Vrv64_pipeline"
echo ">>> rv64_raw_forwarding: PASS"

echo
echo ">>> Building and testing: rv64_forwarding_priority"

"$VERILATOR" --cc --exe --build --sv \
    --top-module rv64_pipeline \
    "-GPROGRAM_ID=2" \
    --Mdir "$BASE_BUILD_DIR/rv64_priority" \
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
    rtl/core/hazard/hazard_detection_unit.sv \
    rtl/core/csr/csr_execute.sv \
    rtl/core/control/branch_decision.sv \
    rtl/core/control/branch_target.sv \
    rtl/core/pipeline/fetch_decode_execute_path.sv \
    rtl/core/pipeline/pipeline_mem_wb.sv \
    rtl/core/writeback/writeback_stage.sv \
    rtl/core/memory/data_memory.sv \
    rtl/core/csr/csr_file.sv \
    rtl/core/exception/exception_controller.sv \
    rtl/core/pipeline/rv64_pipeline.sv \
    "$(pwd)/verification/integration/tb_rv64_forwarding_priority.cpp"

"$BASE_BUILD_DIR/rv64_priority/Vrv64_pipeline"
echo ">>> rv64_forwarding_priority: PASS"

echo
echo ">>> Building and testing: hazard_detection_unit"

"$VERILATOR" --cc --exe --build --sv \
    --top-module hazard_detection_unit \
    --Mdir "$BASE_BUILD_DIR/hazard_detection" \
    rtl/core/hazard/hazard_detection_unit.sv \
    "$(pwd)/verification/unit/hazard_detection_unit/tb_hazard_detection_unit.cpp"

"$BASE_BUILD_DIR/hazard_detection/Vhazard_detection_unit"
echo ">>> hazard_detection_unit: PASS"

echo
echo "======================================"

echo
echo ">>> Building and testing: fetch_decode_local_hazard"

"$VERILATOR" --cc --exe --build --sv \
    --top-module fetch_decode_path \
    --Mdir "$BASE_BUILD_DIR/local_hazard" \
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
    "$(pwd)/verification/integration/tb_fetch_decode_local_hazard.cpp"

"$BASE_BUILD_DIR/local_hazard/Vfetch_decode_path"

echo ">>> fetch_decode_local_hazard: PASS"

echo ">>> load_use_hazard"

"$VERILATOR" --cc --exe --build --sv \
    --top-module fetch_decode_execute_path \
    -GPROGRAM_ID=3 \
    --Mdir "$BASE_BUILD_DIR/load_use_hazard" \
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
    rtl/core/hazard/hazard_detection_unit.sv \
    rtl/core/csr/csr_execute.sv \
    rtl/core/control/branch_decision.sv \
    rtl/core/control/branch_target.sv \
    rtl/core/pipeline/fetch_decode_execute_path.sv \
    "$(pwd)/verification/integration/tb_load_use_hazard.cpp"

"$BASE_BUILD_DIR/load_use_hazard/Vfetch_decode_execute_path"

echo ">>> load_use_hazard: PASS"

echo " ALL TEST SUITES PASSED"
echo "======================================"
