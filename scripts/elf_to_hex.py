#!/usr/bin/env python3
"""Strict ELF64 little-endian RISC-V executable -> dense instruction-word HEX.

Text-only contract: executable read-only PT_LOAD, no BSS/data, identical
physical/virtual addresses, entry at ROM base, implemented instruction subset.
Uses the Python standard library; does not implement a general ELF loader.
"""
import argparse
import json
import struct
from pathlib import Path


class ImageError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ImageError(message)


def unpack(data, offset, fmt):
    size = struct.calcsize(fmt)
    require(0 <= offset <= len(data) and size <= len(data) - offset,
            'truncated ELF structure')
    return struct.unpack_from(fmt, data, offset)


def instruction_supported(word):
    opcode, f3, f7 = word & 127, (word >> 12) & 7, word >> 25
    if opcode == 0x33:
        return f7 == 0 or (f7 == 0x20 and f3 in (0, 5))
    if opcode == 0x13:
        if f3 in (0, 2, 3, 4, 6, 7):
            return True  # Immediate arithmetic/logical operations, signed imm12
        if f3 == 1:
            return word >> 26 == 0  # SLLI, including shamt[5]
        return f3 == 5 and word >> 26 in (0, 16)  # SRLI/SRAI
    if opcode in (0x03, 0x23):
        return f3 == 3  # LD/SD only
    if opcode == 0x63:
        return f3 in (0, 1, 4, 5, 6, 7)
    if opcode in (0x37, 0x17):
        return True  # LUI/AUIPC: every upper-immediate payload is legal
    if opcode == 0x6f:
        return True
    if opcode == 0x67:
        return f3 == 0
    if word == 0x30200073:
        return True
    if opcode == 0x73 and f3 in (1, 2, 3, 5, 6, 7):
        return (word >> 20) in (0x300, 0x305, 0x341, 0x342, 0x343)
    return False


def convert(data, base=0x80000000, words=1024):
    require(isinstance(base, int) and 0 <= base < 2**64 and base % 4 == 0,
            'invalid ROM base')
    require(isinstance(words, int) and 0 < words <= 2**32 - 1,
            'invalid ROM capacity')
    limit = base + words * 4
    require(limit <= 2**64, 'ROM address range wraps')
    require(len(data) >= 64 and data[:4] == b'\x7fELF', 'not an ELF header')
    require(data[4:7] == bytes((2, 1, 1)), 'require ELF64 little-endian version 1')
    (_, etype, machine, version, entry, phoff, shoff, flags, ehsize,
     phentsize, phnum, shentsize, shnum, shstrndx) = unpack(data, 0, '<16sHHIQQQIHHHHHH')
    require(etype == 2 and machine == 243 and version == 1,
            'require linked RISC-V executable')
    require(flags == 0, 'unsupported ELF flags (compressed/float/RVE/other ABI)')
    require(ehsize == 64 and phentsize == 56 and 0 < phnum < 65535,
            'unsupported ELF header or program-header count')
    require(entry == base, 'entry must equal reset/ROM base')
    require(phoff >= 64 and phoff + phnum * 56 <= len(data), 'truncated program headers')
    require(shentsize == 64 and shnum > 0 and 0 < shstrndx < shnum,
            'require regular section headers and string table')
    require(shoff >= 64 and shoff + shnum * 64 <= len(data), 'truncated section headers')
    segments = []
    for i in range(phnum):
        typ, perms, off, va, pa, filesz, memsz, align = unpack(data, phoff + i * 56, '<IIQQQQQQ')
        require(typ not in (2, 3, 7), 'dynamic/interpreted/TLS ELF is unsupported')
        if typ != 1:
            continue
        require(perms == 5, 'loadable sections must be read-only executable text')
        require(filesz > 0 and filesz == memsz, 'empty segment or uninitialized data/BSS')
        require(va == pa and va % 4 == 0 and filesz % 4 == 0, 'segment address/alignment mismatch')
        require(base <= va < limit and va + memsz <= limit, 'segment outside ROM')
        require(off <= len(data) and filesz <= len(data) - off, 'truncated segment')
        require(align in (0, 1) or (align & (align - 1) == 0 and va % align == off % align),
                'invalid segment alignment')
        require(all(va + memsz <= s[0] or s[0] + s[2] <= va for s in segments),
                'overlapping load segments')
        segments.append((va, off, filesz))
    require(segments, 'no loadable text')
    require(any(va <= entry < va + size for va, off, size in segments), 'entry is not loaded')
    sections = [unpack(data, shoff + i * 64, '<IIQQQQIIQQ') for i in range(shnum)]
    strings = sections[shstrndx]
    require(strings[1] == 3 and strings[4] + strings[5] <= len(data), 'invalid section string table')
    names = data[strings[4]:strings[4] + strings[5]]
    allocated = 0
    for nameoff, typ, attrs, addr, off, size, link, info, align, entsize in sections:
        require(nameoff < len(names) and b'\0' in names[nameoff:], 'invalid section name')
        if not attrs & 2 or size == 0:
            continue
        require(typ == 1 and attrs & 4 and not attrs & 1, 'allocated data/BSS/non-code section')
        require(addr % 4 == 0 and size % 4 == 0, 'misaligned code section')
        require(off <= len(data) and size <= len(data) - off, 'truncated code section')
        require(any(va <= addr and addr + size <= va + length and off == so + addr - va
                    for va, so, length in segments), 'code section not mapped consistently')
        allocated += 1
    require(allocated > 0, 'no allocated code sections')
    end = max(va + size for va, off, size in segments)
    image = bytearray(b'\x13\0\0\0' * ((end - base) // 4))
    for va, off, size in segments:
        image[va - base:va - base + size] = data[off:off + size]
    result = []
    for i in range(0, len(image), 4):
        word = int.from_bytes(image[i:i + 4], 'little')
        require(instruction_supported(word), f'unsupported instruction 0x{word:08x} at 0x{base+i:x}')
        result.append(f'{word:08x}')
    return '\n'.join(result) + '\n', {'entry': entry, 'base': base, 'word_count': len(result),
                                         'byte_count': len(image), 'load_segments': len(segments)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('elf', type=Path)
    parser.add_argument('hex', type=Path)
    parser.add_argument('--base', type=lambda s: int(s, 0), default=0x80000000)
    parser.add_argument('--words', type=int, default=1024)
    args = parser.parse_args()
    try:
        require(args.elf.resolve() != args.hex.resolve(), 'input and output paths must differ')
        require(not args.hex.exists() or not args.elf.samefile(args.hex),
                'input and output must not be hard links to the same file')
        text, report = convert(args.elf.read_bytes(), args.base, args.words)
        args.hex.write_text(text, encoding='ascii')
    except (OSError, ImageError) as error:
        parser.exit(1, f'ELF_IMAGE_ERROR: {error}\n')
    print(json.dumps(report, sort_keys=True))


if __name__ == '__main__':
    main()
