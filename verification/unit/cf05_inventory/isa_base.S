/* Decoder oracle: assembled, never executed on the CPU. */
.option norvc
.option norelax
.text
    add x5,x6,x7 /* ADD */
    sub x5,x6,x7 /* SUB */
    sll x5,x6,x7 /* SLL */
    slt x5,x6,x7 /* SLT */
    sltu x5,x6,x7 /* SLTU */
    xor x5,x6,x7 /* XOR */
    srl x5,x6,x7 /* SRL */
    sra x5,x6,x7 /* SRA */
    or x5,x6,x7 /* OR */
    and x5,x6,x7 /* AND */
    addi x5,x6,7 /* ADDI */
    slti x5,x6,7 /* SLTI */
    sltiu x5,x6,7 /* SLTIU */
    xori x5,x6,7 /* XORI */
    ori x5,x6,7 /* ORI */
    andi x5,x6,7 /* ANDI */
    slli x5,x6,63 /* SLLI */
    srli x5,x6,63 /* SRLI */
    srai x5,x6,63 /* SRAI */
    lui x5,0x80000 /* LUI */
    auipc x5,0x12345 /* AUIPC */
    lb x5,0(x6) /* LB */
    lh x5,0(x6) /* LH */
    lw x5,0(x6) /* LW */
    ld x5,0(x6) /* LD */
    lbu x5,0(x6) /* LBU */
    lhu x5,0(x6) /* LHU */
    lwu x5,0(x6) /* LWU */
    sb x7,0(x6) /* SB */
    sh x7,0(x6) /* SH */
    sw x7,0(x6) /* SW */
    sd x7,0(x6) /* SD */
    addiw x5,x6,7 /* ADDIW */
    slliw x5,x6,31 /* SLLIW */
    srliw x5,x6,31 /* SRLIW */
    sraiw x5,x6,31 /* SRAIW */
    addw x5,x6,x7 /* ADDW */
    subw x5,x6,x7 /* SUBW */
    sllw x5,x6,x7 /* SLLW */
    srlw x5,x6,x7 /* SRLW */
    sraw x5,x6,x7 /* SRAW */
    beq x6,x7,.+4 /* BEQ */
    bne x6,x7,.+4 /* BNE */
    blt x6,x7,.+4 /* BLT */
    bge x6,x7,.+4 /* BGE */
    bltu x6,x7,.+4 /* BLTU */
    bgeu x6,x7,.+4 /* BGEU */
    jal x5,.+4 /* JAL */
    jalr x5,0(x6) /* JALR */
    fence rw,rw /* FENCE */
    ecall /* ECALL */
    ebreak /* EBREAK */
