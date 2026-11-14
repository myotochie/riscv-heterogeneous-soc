#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/riscv_toolchain_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-assembled.XXXXXX")}"
mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd)"
BUILD_DIR="$BUILD_ROOT/firmware" bash scripts/build_baremetal.sh
CF04_TEST_ELF="$BUILD_ROOT/firmware/program.elf" \
    python3 -B verification/unit/elf_to_hex/tb_elf_to_hex.py
RTL=(rtl/core/core_pkg.sv)
while IFS= read -r file; do
    [[ "$file" == rtl/core/core_pkg.sv ]] || RTL+=("$file")
done < <(find rtl/core -name '*.sv' -type f | sort)
"$VERILATOR" --cc --exe --build --sv --top-module rv64_pipeline \
    "-GIMEM_FILE=\"$BUILD_ROOT/firmware/program.hex\"" --Mdir "$BUILD_ROOT/pipeline" \
    "${RTL[@]}" "$PWD/verification/integration/tb_baremetal_program.cpp" \
    > "$BUILD_ROOT/pipeline-build.log" 2>&1
"$BUILD_ROOT/pipeline/Vrv64_pipeline"
echo "PASS bare-metal ELF-to-HEX integration; logs: $BUILD_ROOT"
