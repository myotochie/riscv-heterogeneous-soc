#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/verilator_env.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/rv64_csr_commit_integration}"
TB="$ROOT/verification/unit/rv64_pipeline/tb_csr_commit_integration.cpp"

cd "$ROOT"


test -x "$VERILATOR" || {
    echo "[ERROR] Verilator not found: $VERILATOR"
    exit 1
}

mkdir -p "$BUILD_DIR"

RTL=("$ROOT/rtl/core/core_pkg.sv")

while IFS= read -r file; do
    [[ "$file" == "$ROOT/rtl/core/core_pkg.sv" ]] && continue
    RTL+=("$file")
done < <(find "$ROOT/rtl/core" -type f -name '*.sv' | sort)

"$VERILATOR" \
    --cc --exe --build \
    --top-module rv64_pipeline \
    -GPROGRAM_ID=14 \
    --Mdir "$BUILD_DIR" \
    -Wno-fatal \
    "${RTL[@]}" \
    "$TB" \
    > "$BUILD_DIR/build.log" 2>&1 || {
        tail -n 60 "$BUILD_DIR/build.log"
        exit 1
    }

"$BUILD_DIR/Vrv64_pipeline"
