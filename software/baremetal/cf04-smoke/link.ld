OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { IMEM (rx) : ORIGIN = 0x80000000, LENGTH = 4096 }
PHDRS { instructions PT_LOAD FLAGS(5); }
SECTIONS
{
    .text ORIGIN(IMEM) : ALIGN(4) {
        KEEP(*(.text.start))
        *(.text .text.*)
    } > IMEM :instructions
    .forbidden : {
        *(.data .data.* .sdata .sdata.*)
        *(.rodata .rodata.* .bss .bss.* .sbss .sbss.*)
        *(COMMON)
    } > IMEM :instructions
    .riscv.attributes 0 : { *(.riscv.attributes) }
    /DISCARD/ : { *(.comment .note.GNU-stack) }
    ASSERT(SIZEOF(.text) <= LENGTH(IMEM), "text exceeds instruction ROM")
    ASSERT(_start == ORIGIN(IMEM), "entry must match reset PC")
    ASSERT((SIZEOF(.text) % 4) == 0, "text must contain whole 32-bit words")
    ASSERT(SIZEOF(.forbidden) == 0, "data/rodata/bss startup is not implemented")
}
