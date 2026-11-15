#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/riscv_c_toolchain_env.sh"
cd "$(dirname "$0")/.."
BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-c-inventory.XXXXXX")}"
python3 -B scripts/inspect_c_toolchain.py --output "$BUILD_ROOT"
