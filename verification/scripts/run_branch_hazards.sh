#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

run_program() {
    local program="$1"
    local build_dir="obj_dir/branch_pipeline_${program}"

    echo "===================================="
    echo " BRANCH HAZARD PROGRAM ${program}"
    echo "===================================="

    verilator --cc --exe --build --sv \
        --top-module rv64_pipeline \
        "-GPROGRAM_ID=${program}" \
        --Mdir "$build_dir" \
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
        "$(pwd)/verification/integration/tb_branch_hazards.cpp"

    "./${build_dir}/Vrv64_pipeline" "$program"
}

run_program 32
run_program 33

echo "===================================="
echo "[PASS] BOTH BRANCH PROGRAMS"
echo "===================================="
