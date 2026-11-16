#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/riscv_toolchain_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-upper.XXXXXX")}"
mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd)"
"$VERILATOR" --cc --exe --build --sv --top-module upper_probe --Mdir "$BUILD_ROOT/unit" \
    rtl/core/core_pkg.sv rtl/core/decoder/decoder.sv rtl/core/imm_gen/imm_gen.sv \
    rtl/core/alu/alu.sv rtl/core/hazard/forwarding_mux.sv rtl/core/hazard/hazard_detection_unit.sv \
    rtl/core/execute/execute_stage.sv verification/unit/upper_immediates/upper_probe.sv \
    "$PWD/verification/unit/upper_immediates/tb_upper.cpp" > "$BUILD_ROOT/unit-build.log" 2>&1
"$BUILD_ROOT/unit/Vupper_probe"
python3 -B verification/unit/upper_immediates/make_programs.py "$BUILD_ROOT/programs"
cp "$BUILD_ROOT/programs/data.hex" "$BUILD_ROOT/program.hex"
RTL=(rtl/core/core_pkg.sv)
while IFS= read -r file; do
    [[ "$file" == rtl/core/core_pkg.sv ]] || RTL+=("$file")
done < <(find rtl/core -name '*.sv' -type f | sort)
"$VERILATOR" --cc --exe --build --sv --public-flat-rw --top-module rv64_pipeline \
    "-GIMEM_FILE=\"$BUILD_ROOT/program.hex\"" --Mdir "$BUILD_ROOT/pipeline" \
    "${RTL[@]}" "$PWD/verification/integration/tb_upper_pipeline.cpp" > "$BUILD_ROOT/pipeline-build.log" 2>&1
for scenario in data branch trap mret control edges memory control_pc jump; do
    cp "$BUILD_ROOT/programs/$scenario.hex" "$BUILD_ROOT/program.hex"
    modes=(normal)
    [[ "$scenario" != control && "$scenario" != control_pc ]] || modes+=(stall flush reset)
    for mode in "${modes[@]}"; do
        "$BUILD_ROOT/pipeline/Vrv64_pipeline" "$BUILD_ROOT/programs/$scenario.expected" "$scenario" "$mode"
    done
done
echo "PASS upper-immediate suite; evidence: $BUILD_ROOT"
