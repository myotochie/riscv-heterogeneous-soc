#!/usr/bin/env bash
# Resolve dependencies only: no installation or PATH mutation.
if [[ -z "${RISCV_PREFIX:-}" ]]; then
    if command -v riscv64-unknown-elf-as >/dev/null 2>&1; then
        RISCV_PREFIX=riscv64-unknown-elf-
    else
        RISCV_PREFIX="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.tools/binutils-riscv64-unknown-elf-2.35.1/usr/bin/riscv64-unknown-elf-"
    fi
fi
for riscv_name in as ld objcopy objdump readelf; do
    if ! command -v "${RISCV_PREFIX}${riscv_name}" >/dev/null 2>&1; then
        echo "[ERROR] Missing ${RISCV_PREFIX}${riscv_name}; provide GNU RISC-V Binutils or RISCV_PREFIX" >&2
        return 1
    fi
done
RISCV_AS="$(command -v "${RISCV_PREFIX}as")"
RISCV_LD="$(command -v "${RISCV_PREFIX}ld")"
RISCV_OBJCOPY="$(command -v "${RISCV_PREFIX}objcopy")"
RISCV_OBJDUMP="$(command -v "${RISCV_PREFIX}objdump")"
RISCV_READELF="$(command -v "${RISCV_PREFIX}readelf")"
export RISCV_PREFIX RISCV_AS RISCV_LD RISCV_OBJCOPY RISCV_OBJDUMP RISCV_READELF
