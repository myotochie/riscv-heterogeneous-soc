#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-/tmp/rv64_cf03}"
mkdir -p "$BUILD_ROOT"
# Only address zero is read before a program initializes its own data.
printf '@0\n00\n00\n00\n00\n00\n00\n00\n00\n' > "$BUILD_ROOT/initial.hex"
RTL=(rtl/core/core_pkg.sv)
while IFS= read -r file; do
    [[ "$file" == rtl/core/core_pkg.sv ]] || RTL+=("$file")
done < <(find rtl/core -name '*.sv' -type f | sort)
for id in 36 37 38 39 40 41 42 43 44 45 46 47; do
    build="$BUILD_ROOT/program_$id"
    log="$BUILD_ROOT/program_$id.log"
    if ! "$VERILATOR" --cc --exe --build --sv --public-flat-rw --top-module rv64_pipeline \
        "-GMEM_INIT_FILE=\"$BUILD_ROOT/initial.hex\"" \
        -GPROGRAM_ID="$id" --Mdir "$build" "${RTL[@]}" \
        "$PWD/verification/integration/tb_jump_pipeline.cpp" > "$log" 2>&1; then
        tail -60 "$log"
        exit 1
    fi
    modes=(0)
    [[ "$id" != 36 ]] || modes+=(1 2 3 7 8 9)
    [[ "$id" != 38 ]] || modes+=(4 5 6)
    for mode in "${modes[@]}"; do
        if ! "$build/Vrv64_pipeline" "$id" "$mode" >> "$log" 2>&1; then
            tail -80 "$log"
            exit 1
        fi
        echo "[PASS] CF-03 PROGRAM_ID=$id mode=$mode"
    done
done
echo "[PASS] CF-03 jump integration; logs: $BUILD_ROOT"
