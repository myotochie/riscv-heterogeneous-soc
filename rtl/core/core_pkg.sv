package core_pkg;

    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA,
        ALU_SLT,
        ALU_SLTU,
        ALU_ADDW, ALU_SUBW, ALU_SLLW, ALU_SRLW, ALU_SRAW
    } alu_op_t;

endpackage
