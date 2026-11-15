/* Inspection layout only: no startup, no promise that e_entry == reset PC. */
OUTPUT_ARCH(riscv)
ENTRY(probe_entry)
CF05_RAM_BASE = DEFINED(CF05_DATA_BASE) ? CF05_DATA_BASE : 0x100;
MEMORY {
    IMEM (rx) : ORIGIN = 0x80000000, LENGTH = 4096
    DMEM (rw) : ORIGIN = CF05_RAM_BASE, LENGTH = 4096 - CF05_RAM_BASE
}
PHDRS { code PT_LOAD FLAGS(5); data PT_LOAD FLAGS(6); }
SECTIONS {
    .text ORIGIN(IMEM) : { *(.text .text.hot .text.unlikely .text.startup .text.exit) } > IMEM :code
    .late (ORIGIN(IMEM) + 0xf00) : { *(.text.late) } > IMEM :code
    .rodata ORIGIN(DMEM) : { *(.rodata .rodata.* .srodata .srodata.*) } > DMEM :data
    .data : ALIGN(8) { *(.data .data.* .sdata .sdata.*) } > DMEM :data
    .bss (NOLOAD) : ALIGN(8) { *(.bss .bss.* .sbss .sbss.*) *(COMMON) } > DMEM :data
    .riscv.attributes 0 : { *(.riscv.attributes) }
    /DISCARD/ : { *(.comment .note.GNU-stack) }
}
