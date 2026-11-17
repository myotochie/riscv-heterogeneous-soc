#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/riscv_toolchain_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-word-memory.XXXXXX")}"; mkdir -p "$BUILD_ROOT"; BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd)"
"$VERILATOR" --cc --exe --build --sv --top-module data_memory --Mdir "$BUILD_ROOT/unit" rtl/core/memory/data_memory.sv "$PWD/verification/unit/word_memory/tb_word_memory.cpp" > "$BUILD_ROOT/unit-build.log" 2>&1
"$BUILD_ROOT/unit/Vdata_memory"
python3 -B verification/unit/word_memory/make_programs.py "$BUILD_ROOT/programs"
cp "$BUILD_ROOT/programs/data.hex" "$BUILD_ROOT/program.hex"
RTL=(rtl/core/core_pkg.sv)
while IFS= read -r file; do [[ "$file" == rtl/core/core_pkg.sv ]] || RTL+=("$file"); done < <(find rtl/core -name '*.sv' -type f | sort)
"$VERILATOR" --cc --exe --build --sv --public-flat-rw --top-module rv64_pipeline "-GIMEM_FILE=\"$BUILD_ROOT/program.hex\"" --Mdir "$BUILD_ROOT/pipeline" "${RTL[@]}" "$PWD/verification/integration/tb_word_memory_pipeline.cpp" > "$BUILD_ROOT/pipeline-build.log" 2>&1
for scenario in data load_misaligned store_misaligned load_range store_range; do
 cp "$BUILD_ROOT/programs/$scenario.hex" "$BUILD_ROOT/program.hex"
 "$BUILD_ROOT/pipeline/Vrv64_pipeline" "$BUILD_ROOT/programs/$scenario.expected"
done
echo "PASS word memory suite; evidence: $BUILD_ROOT"
