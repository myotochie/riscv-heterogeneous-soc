#!/usr/bin/env bash
# Sourced by runners. No installation, implicit /opt lookup, or filesystem cleanup.
VERILATOR="${VERILATOR:-verilator}"
if ! VERILATOR="$(command -v "$VERILATOR")"; then
    echo "[ERROR] Set VERILATOR to an installed Verilator executable" >&2
    return 1
fi
export VERILATOR
