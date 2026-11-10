#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/rv64_csr_mem_wb_observe}"

cd "$ROOT"

test -x "$VERILATOR" || {
    echo "[ERROR] Verilator not found"
    exit 1
}

mkdir -p "$BUILD_DIR"

RTL=("$ROOT/rtl/core/core_pkg.sv")

while IFS= read -r file; do
    [[ "$file" == "$ROOT/rtl/core/core_pkg.sv" ]] && continue
    RTL+=("$file")
done < <(find "$ROOT/rtl/core" -type f -name '*.sv' | sort)

"$VERILATOR" \
    --cc \
    --public-flat-rw \
    --top-module rv64_pipeline \
    -GPROGRAM_ID=19 \
    --Mdir "$BUILD_DIR" \
    -Wno-fatal \
    "${RTL[@]}" \
    > "$BUILD_DIR/generate.log" 2>&1 || {
        tail -n 60 "$BUILD_DIR/generate.log"
        exit 1
    }

HEADER="$BUILD_DIR/Vrv64_pipeline___024root.h"

echo "===== INTERNAL SIGNAL CHECK ====="

for signal in \
    rv64_pipeline__DOT__u_frontend__DOT__id_ex_instr \
    rv64_pipeline__DOT__u_frontend__DOT__forward_a
do
    if grep -Fq "$signal" "$HEADER"; then
        echo "[FOUND] $signal"
    else
        echo "[ERROR] Signal unavailable: $signal"
        exit 1
    fi
done

echo "===== BUILD INSTRUMENTED TEST ====="

"$VERILATOR" \
    --cc --exe --build \
    --public-flat-rw \
    --top-module rv64_pipeline \
    -GPROGRAM_ID=19 \
    --Mdir "$BUILD_DIR" \
    -Wno-fatal \
    "${RTL[@]}" \
    "$ROOT/verification/unit/rv64_pipeline/tb_csr_mem_wb_observe.cpp" \
    > "$BUILD_DIR/build.log" 2>&1 || {
        tail -n 60 "$BUILD_DIR/build.log"
        exit 1
    }

echo "===== RUN ====="
"$BUILD_DIR/Vrv64_pipeline"
