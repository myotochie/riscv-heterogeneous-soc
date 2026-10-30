#!/usr/bin/env bash
set -Eeuo pipefail

# Locate repository independently of the current directory.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-/tmp/rv64_memory_traps}"
TB="$ROOT/verification/unit/rv64_pipeline/tb_memory_traps.cpp"

cd "$ROOT"

command -v verilator >/dev/null || {
    echo "[ERROR] Verilator is not installed"
    exit 1
}

test -f "$TB" || {
    echo "[ERROR] Missing testbench: $TB"
    exit 1
}

mkdir -p "$BUILD_ROOT"

# SystemVerilog packages must be compiled before modules
# importing them.
RTL=("$ROOT/rtl/core/core_pkg.sv")

while IFS= read -r file; do
    [[ "$file" == "$ROOT/rtl/core/core_pkg.sv" ]] && continue
    RTL+=("$file")
done < <(find "$ROOT/rtl/core" -type f -name '*.sv' | sort)

passed=0
failed=0

for id in 10 11 12 13; do
    echo
    echo "======================================"
    echo " PROGRAM_ID=$id"
    echo "======================================"

    BUILD_DIR="$BUILD_ROOT/program_${id}"
    LOG="$BUILD_ROOT/program_${id}.log"

    mkdir -p "$BUILD_DIR"

    if verilator \
        --cc --exe --build \
        --top-module rv64_pipeline \
        -GPROGRAM_ID="$id" \
        --Mdir "$BUILD_DIR" \
        -Wno-fatal \
        "${RTL[@]}" \
        "$TB" > "$LOG" 2>&1 \
        && "$BUILD_DIR/Vrv64_pipeline" "$id" >> "$LOG" 2>&1; then

        grep -E '^\[TRAP\]|Tests run:|Tests failed:' "$LOG" || true
        echo "[PASS] PROGRAM_ID=$id"
        ((passed+=1))
    else
        echo "[FAIL] PROGRAM_ID=$id"
        tail -n 35 "$LOG"
        ((failed+=1))
    fi
done

echo
echo "======================================"
echo " RV64 MEMORY TRAP REGRESSION"
echo "======================================"
echo "Programs passed: $passed"
echo "Programs failed: $failed"
echo "Logs: $BUILD_ROOT"

if ((failed != 0)); then
    exit 1
fi

echo "[PASS] All memory trap programs"
