#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-/tmp/rv64_datapath_regression}"
mkdir -p "$BUILD_ROOT"
RTL=(rtl/core/core_pkg.sv)
while IFS= read -r file; do
    [[ "$file" == rtl/core/core_pkg.sv ]] || RTL+=("$file")
done < <(find rtl/core -name '*.sv' -type f | sort)
run() {
    local top="$1" tb="$2" name="$3"; shift 3
    local build="$BUILD_ROOT/$name" log="$BUILD_ROOT/$name.log"
    local sources=()
    case "$top" in
        rv64_pipeline) sources=("${RTL[@]}") ;;
        execute_stage) sources=(rtl/core/core_pkg.sv rtl/core/alu/alu.sv
            rtl/core/hazard/forwarding_mux.sv rtl/core/execute/execute_stage.sv) ;;
        *) sources=("$(find rtl/core -name "$top.sv" -type f)") ;;
    esac
    if ! "$VERILATOR" --cc --exe --build --sv --top-module "$top" --Mdir "$build" \
        "$@" "${sources[@]}" "$PWD/$tb" > "$log" 2>&1; then
        tail -50 "$log"; return 1
    fi
    if ! "$build/V$top" >> "$log" 2>&1; then
        tail -50 "$log"; return 1
    fi
    echo "[PASS] $name"
}
run csr_file verification/unit/csr/tb_csr_file.cpp csr_file
run forwarding_unit verification/unit/forwarding_unit/tb_forwarding_unit.cpp forwarding_unit
run forwarding_mux verification/unit/forwarding_mux/tb_forwarding_mux.cpp forwarding_mux
run data_memory verification/unit/data_memory/tb_data_memory.cpp data_memory
run data_memory verification/unit/data_memory/tb_memory_fault_classification.cpp memory_fault_classification
run execute_stage verification/integration/tb_execute_forwarding.cpp execute_forwarding "-GENABLE_FORWARDING=1'b1"
run pipeline_ex_mem verification/unit/pipeline_ex_mem/tb_pipeline_ex_mem.cpp pipeline_ex_mem
run rv64_pipeline verification/integration/tb_rv64_pipeline.cpp pipeline
printf '@40\n15\n00\n00\n00\n00\n00\n00\n00\n' > "$BUILD_ROOT/load.hex"
run rv64_pipeline verification/integration/tb_rv64_load.cpp load -GPROGRAM_ID=4 \
    "-GMEM_INIT_FILE=\"$BUILD_ROOT/load.hex\""
run rv64_pipeline verification/integration/tb_rv64_store.cpp store -GPROGRAM_ID=5
run rv64_pipeline verification/integration/tb_rv64_memory_offsets.cpp memory_offsets -GPROGRAM_ID=6
printf '@40\n88\n77\n66\n55\n44\n33\n22\n11\n' > "$BUILD_ROOT/full_width.hex"
run rv64_pipeline verification/integration/tb_rv64_full_width.cpp full_width -GPROGRAM_ID=7 \
    "-GMEM_INIT_FILE=\"$BUILD_ROOT/full_width.hex\""
# The historical invalid_load benches predate precise traps and expect execution
# to continue after a fault. Active fault coverage is run_memory_traps.sh and
# the precise-trap test below. Keep those historical sources unchanged.
echo "[HISTORICAL] tb_rv64_invalid_load.cpp: expects continuation after a fault (pre-existing)"
echo "[HISTORICAL] tb_rv64_invalid_load_dependency.cpp: expects continuation after a fault (pre-existing)"
run rv64_pipeline verification/unit/rv64_pipeline/tb_precise_trap.cpp precise_trap -GPROGRAM_ID=10
echo "[PASS] Datapath regression; logs: $BUILD_ROOT"
