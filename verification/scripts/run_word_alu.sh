#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/riscv_toolchain_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-word.XXXXXX")}"; mkdir -p "$BUILD_ROOT"; BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd)"
"$VERILATOR" --cc --exe --build --sv --top-module upper_probe --Mdir "$BUILD_ROOT/unit" \
 rtl/core/core_pkg.sv rtl/core/decoder/decoder.sv rtl/core/imm_gen/imm_gen.sv rtl/core/alu/alu.sv \
 rtl/core/hazard/forwarding_mux.sv rtl/core/hazard/hazard_detection_unit.sv rtl/core/execute/execute_stage.sv \
 verification/unit/upper_immediates/upper_probe.sv "$PWD/verification/unit/word_alu/tb_word.cpp" > "$BUILD_ROOT/unit-build.log" 2>&1
"$BUILD_ROOT/unit/Vupper_probe"
"$RISCV_AS" -march=rv64i -mabi=lp64 -mno-relax -o "$BUILD_ROOT/program.o" verification/unit/word_alu/program.S
"$RISCV_LD" --no-relax -Ttext=0x80000000 -e 0x80000000 -o "$BUILD_ROOT/program.elf" "$BUILD_ROOT/program.o"
"$RISCV_OBJCOPY" -O binary --only-section=.text "$BUILD_ROOT/program.elf" "$BUILD_ROOT/program.bin"
python3 - "$BUILD_ROOT/program.bin" "$BUILD_ROOT/program.hex" <<'PY'
import pathlib,sys
b=pathlib.Path(sys.argv[1]).read_bytes()
assert len(b)%4==0
pathlib.Path(sys.argv[2]).write_text(''.join(f'{int.from_bytes(b[i:i+4],"little"):08x}\n' for i in range(0,len(b),4)))
PY
RTL=(rtl/core/core_pkg.sv)
while IFS= read -r file; do [[ "$file" == rtl/core/core_pkg.sv ]] || RTL+=("$file"); done < <(find rtl/core -name '*.sv' -type f | sort)
"$VERILATOR" --cc --exe --build --sv --public-flat-rw --top-module rv64_pipeline "-GIMEM_FILE=\"$BUILD_ROOT/program.hex\"" --Mdir "$BUILD_ROOT/pipeline" "${RTL[@]}" "$PWD/verification/integration/tb_word_pipeline.cpp" > "$BUILD_ROOT/pipeline-build.log" 2>&1
"$BUILD_ROOT/pipeline/Vrv64_pipeline"
echo "PASS word ALU suite; evidence: $BUILD_ROOT"
