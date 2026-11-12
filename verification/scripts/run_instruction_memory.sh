#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-imem.XXXXXX")}"
mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd)"
# Invalid-image tests deliberately abort; keep core dumps out of the workspace.
ulimit -c 0
image="$BUILD_ROOT/instructions.hex"
valid_image() { printf '%s\n' 00500093 00700113 00900193 0000006f > "$image"; }
valid_image
"$VERILATOR" --cc --exe --build --sv --top-module instruction_memory \
    -GWORDS=4 "-GINIT_FILE=\"$image\"" --Mdir "$BUILD_ROOT/rom" \
    rtl/core/memory/instruction_memory.sv "$PWD/verification/unit/instruction_memory/tb_instruction_memory.cpp" > "$BUILD_ROOT/rom-build.log" 2>&1
"$BUILD_ROOT/rom/Vinstruction_memory"
printf '%s\n' 00500093 00700113 > "$image"
"$BUILD_ROOT/rom/Vinstruction_memory" partial
expect_failure() {
    local marker="$1"; shift
    if "$@" > "$BUILD_ROOT/negative.log" 2>&1; then
        echo "FAIL: expected $marker" >&2; exit 1
    fi
    if ! grep -q "$marker" "$BUILD_ROOT/negative.log"; then
        cat "$BUILD_ROOT/negative.log"; exit 1
    fi
    echo "PASS expected failure: $marker"
}
for bad in 0000001 000000001 0000000g 0000000x @0000000 0000_013; do
    printf '%s\n' "$bad" > "$image"
    expect_failure IMEM_FORMAT "$BUILD_ROOT/rom/Vinstruction_memory"
done
: > "$image"
expect_failure IMEM_FORMAT "$BUILD_ROOT/rom/Vinstruction_memory"
valid_image
printf '00000013\n' >> "$image"
expect_failure IMEM_SIZE "$BUILD_ROOT/rom/Vinstruction_memory"
# Missing path, then replace the fixture before the next test.
mv "$image" "$BUILD_ROOT/saved.hex"
expect_failure IMEM_FILE "$BUILD_ROOT/rom/Vinstruction_memory"
mv "$BUILD_ROOT/saved.hex" "$image"
valid_image
"$VERILATOR" --cc --exe --build --sv --top-module fetch_path \
    -GIMEM_WORDS=4 "-GIMEM_FILE=\"$image\"" --Mdir "$BUILD_ROOT/fetch" \
    rtl/core/pc/pc.sv rtl/core/pipeline/pipeline_if_id.sv \
    rtl/core/memory/instruction_memory.sv rtl/core/pipeline/fetch_path.sv \
    "$PWD/verification/integration/tb_external_fetch.cpp" > "$BUILD_ROOT/fetch-build.log" 2>&1
"$BUILD_ROOT/fetch/Vfetch_path"
expect_failure IMEM_FETCH_ADDRESS "$BUILD_ROOT/fetch/Vfetch_path" invalid
# Encoded smoke fixture, no cross compiler required for CF-04.2.
printf '%s\n' 04000113 02800293 010000ef 00513023 00013503 0000006f 00228293 00008067 > "$image"
RTL=(rtl/core/core_pkg.sv)
while IFS= read -r file; do
    [[ "$file" == rtl/core/core_pkg.sv ]] || RTL+=("$file")
done < <(find rtl/core -name '*.sv' -type f | sort)
"$VERILATOR" --cc --exe --build --sv --top-module rv64_pipeline \
    "-GIMEM_FILE=\"$image\"" --Mdir "$BUILD_ROOT/pipeline" "${RTL[@]}" \
    "$PWD/verification/integration/tb_external_program.cpp" > "$BUILD_ROOT/pipeline-build.log" 2>&1
"$BUILD_ROOT/pipeline/Vrv64_pipeline"
echo "PASS instruction-memory suite; logs: $BUILD_ROOT"
