.option norvc
.option norelax
.text
    addi x1,x0,-1
    addiw x2,x1,1
    slliw x3,x1,31
    srliw x4,x3,31
    sraiw x5,x3,31
    addw x6,x1,x1
    subw x7,x0,x3
    srlw x8,x3,x1
    sraw x9,x3,x1
    addiw x10,x0,-1
    sllw x11,x10,x1
    sd x10,0(x0)
    ld x12,0(x0)
    addiw x13,x12,1
    addi x0,x0,0
    addw x0,x1,x1
    .word 0x0200129b
    .word 0x0200529b
    .word 0x020002bb
    beq x13,x0,good
    addi x30,x0,99
good:
    addiw x14,x0,1
done: jal x0,done
