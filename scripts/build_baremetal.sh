#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/riscv_toolchain_env.sh"
cd "$(dirname "$0")/.."
BUILD_DIR="${BUILD_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-baremetal.XXXXXX")}"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
{
    for tool in "$RISCV_AS" "$RISCV_LD" "$RISCV_OBJCOPY" "$RISCV_OBJDUMP" "$RISCV_READELF"; do
        "$tool" --version
    done
} > "$BUILD_DIR/toolchain.log"
"$RISCV_AS" -march=rv64i -mabi=lp64 -mno-relax \
    -o "$BUILD_DIR/program.o" software/baremetal/cf04-smoke/start.S
"$RISCV_LD" --no-relax -T software/baremetal/cf04-smoke/link.ld \
    -Map="$BUILD_DIR/program.map" -o "$BUILD_DIR/program.elf" "$BUILD_DIR/program.o"
"$RISCV_READELF" -h -l -S -A -W "$BUILD_DIR/program.elf" > "$BUILD_DIR/program.readelf.log"
"$RISCV_OBJDUMP" -d -M no-aliases "$BUILD_DIR/program.elf" > "$BUILD_DIR/program.disassembly.log"
# Validate ELF metadata and instructions before creating a memory image.
python3 -B scripts/elf_to_hex.py "$BUILD_DIR/program.elf" "$BUILD_DIR/program.hex" > "$BUILD_DIR/image.log"
"$RISCV_OBJCOPY" -O binary --only-section=.text "$BUILD_DIR/program.elf" "$BUILD_DIR/program.bin"
# Independent extraction: objcopy bytes must agree with the word image.
python3 -B - "$BUILD_DIR" <<'PY'
import pathlib,sys,hashlib,json
root=pathlib.Path(sys.argv[1])
words=root.joinpath('program.hex').read_text().split()
image=b''.join(int(w,16).to_bytes(4,'little') for w in words)
assert image==root.joinpath('program.bin').read_bytes(), 'objcopy/HEX mismatch'
report={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in
        [root/'program.elf',root/'program.bin',root/'program.hex']}
root.joinpath('program.sha256.json').write_text(json.dumps(report,indent=2)+'\n')
print('Built bare-metal image:',root)
PY
