#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/riscv_toolchain_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-immediate.XXXXXX")}"
mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd)"
"$VERILATOR" --cc --exe --build --sv --top-module upper_probe --Mdir "$BUILD_ROOT/unit" \
    rtl/core/core_pkg.sv rtl/core/decoder/decoder.sv rtl/core/imm_gen/imm_gen.sv \
    rtl/core/alu/alu.sv rtl/core/hazard/forwarding_mux.sv rtl/core/hazard/hazard_detection_unit.sv \
    rtl/core/execute/execute_stage.sv verification/unit/upper_immediates/upper_probe.sv \
    "$PWD/verification/unit/immediate_alu/tb_immediate.cpp" > "$BUILD_ROOT/unit-build.log" 2>&1
"$BUILD_ROOT/unit/Vupper_probe"
"$VERILATOR" --cc --exe --build --sv --top-module rv64_datapath --Mdir "$BUILD_ROOT/teaching" \
    rtl/core/core_pkg.sv rtl/core/decoder/decoder.sv rtl/core/imm_gen/imm_gen.sv \
    rtl/core/alu/alu.sv rtl/core/regfile/regfile.sv rtl/core/rv64_datapath.sv \
    "$PWD/verification/unit/immediate_alu/tb_teaching_contract.cpp" > "$BUILD_ROOT/teaching-build.log" 2>&1
"$BUILD_ROOT/teaching/Vrv64_datapath"
python3 -B verification/unit/immediate_alu/make_programs.py "$BUILD_ROOT/programs"
cp "$BUILD_ROOT/programs/data.hex" "$BUILD_ROOT/program.hex"
RTL=(rtl/core/core_pkg.sv)
while IFS= read -r file; do
    [[ "$file" == rtl/core/core_pkg.sv ]] || RTL+=("$file")
done < <(find rtl/core -name '*.sv' -type f | sort)
"$VERILATOR" --cc --exe --build --sv --public-flat-rw --top-module rv64_pipeline \
    "-GIMEM_FILE=\"$BUILD_ROOT/program.hex\"" --Mdir "$BUILD_ROOT/pipeline" \
    "${RTL[@]}" "$PWD/verification/integration/tb_immediate_pipeline.cpp" > "$BUILD_ROOT/pipeline-build.log" 2>&1
for scenario in data reserved branch trap mret control control_shift consumers; do
    cp "$BUILD_ROOT/programs/$scenario.hex" "$BUILD_ROOT/program.hex"
    modes=(normal)
    [[ "$scenario" != control && "$scenario" != control_shift ]] || modes+=(stall flush reset)
    for mode in "${modes[@]}"; do
        "$BUILD_ROOT/pipeline/Vrv64_pipeline" "$BUILD_ROOT/programs/$scenario.expected" "$scenario" "$mode"
    done
done
echo "PASS immediate ALU suite; evidence: $BUILD_ROOT"
