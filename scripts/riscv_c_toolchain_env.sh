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
# GCC may report a symlink or a path containing ../ to the same tool.
# Compare executable identity after PATH lookup rather than path spelling.
_cf05_check_compiler_tools() (
    target=$("$RISCV_GCC" -dumpmachine) || exit 1
    reported_as=$("$RISCV_GCC" -B "$RISCV_GCC_TOOL_PREFIX" -print-prog-name=as) || exit 1
    reported_ld=$("$RISCV_GCC" -B "$RISCV_GCC_TOOL_PREFIX" -print-prog-name=ld) || exit 1
    resolved_as=$(command -v "$reported_as") || resolved_as=''
    resolved_ld=$(command -v "$reported_ld") || resolved_ld=''
    if [[ "$target" != riscv64-unknown-elf ||
          ! -x "$resolved_as" || ! -x "$resolved_ld" ||
          ! "$resolved_as" -ef "$RISCV_AS" ||
          ! "$resolved_ld" -ef "$RISCV_LD" ]]; then
        echo '[ERROR] GCC target/as/ld do not match the selected bare-metal Binutils' >&2
        printf 'GCC: %s\ntarget: %s\nselected as: %s\nreported as: %s\nresolved as: %s\nselected ld: %s\nreported ld: %s\nresolved ld: %s\n' \
            "$RISCV_GCC" "$target" "$RISCV_AS" "$reported_as" "$resolved_as" \
            "$RISCV_LD" "$reported_ld" "$resolved_ld" >&2
        exit 1
    fi
)
if ! _cf05_check_compiler_tools; then
    unset -f _cf05_check_compiler_tools
    return 1
fi
unset -f _cf05_check_compiler_tools
export RISCV_GCC RISCV_GCC_TOOL_PREFIX
