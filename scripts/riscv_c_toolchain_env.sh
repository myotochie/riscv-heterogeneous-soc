#!/usr/bin/env bash
# Compiler dependency for CF-05 inspection. No installation or PATH mutation.
source "$(dirname "${BASH_SOURCE[0]}")/riscv_toolchain_env.sh" || return 1
if [[ -z "${RISCV_GCC:-}" ]]; then
    if command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
        RISCV_GCC=riscv64-unknown-elf-gcc
    else
        RISCV_GCC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.tools/gcc-riscv64-unknown-elf-10.2.0/usr/bin/riscv64-unknown-elf-gcc"
    fi
fi
if ! RISCV_GCC="$(command -v "$RISCV_GCC")"; then
    echo '[ERROR] Provide RISC-V GCC via RISCV_GCC or install gcc-riscv64-unknown-elf' >&2
    return 1
fi
RISCV_GCC_TOOL_PREFIX="${RISCV_AS%as}"
if [[ "$("$RISCV_GCC" -dumpmachine)" != riscv64-unknown-elf ||
      "$("$RISCV_GCC" -B "$RISCV_GCC_TOOL_PREFIX" -print-prog-name=as)" != "$RISCV_AS" ||
      "$("$RISCV_GCC" -B "$RISCV_GCC_TOOL_PREFIX" -print-prog-name=ld)" != "$RISCV_LD" ]]; then
    echo '[ERROR] GCC target/as/ld do not match the selected bare-metal Binutils' >&2
    return 1
fi
export RISCV_GCC RISCV_GCC_TOOL_PREFIX
