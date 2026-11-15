#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/riscv_c_toolchain_env.sh"
cd "$(dirname "$0")/../.."
BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-cf05.XXXXXX")}"
BUILD_ROOT="$BUILD_ROOT/inspection" bash scripts/inspect_c_toolchain.sh
CF05_INVENTORY_ROOT="$BUILD_ROOT/inspection" python3 -B verification/unit/cf05_inventory/tb_inventory.py
echo 'CF05 inspection checks complete; generated C was NOT executed on RTL'
