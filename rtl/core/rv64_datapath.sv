
module rv64_datapath (
    input  logic        clk,
    input  logic [31:0] instr,

    output logic        illegal_instr,
    output logic [63:0] result,
    output logic [63:0] rs1_value,
    output logic [63:0] rs2_value
);

    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;

    core_pkg::alu_op_t alu_op;
    logic reg_write;
    logic alu_src;
    logic decoded_illegal;
    logic supported_opcode;

    // This teaching datapath has no PC, memory, or CSR execution path.
    // Keep its original R-type/ADDI contract independent of decoder growth.
    assign supported_opcode = (instr[6:0] == 7'b0110011) ||
                              (instr[6:0] == 7'b0010011);
    assign illegal_instr = decoded_illegal || !supported_opcode;

    logic [63:0] immediate;
    logic [63:0] alu_operand_b;
    logic [63:0] writeback_data;

    // Instruction decoding and control generation.
    decoder u_decoder (
        // CSR/MRET outputs are unused by the legacy datapath.
        .csr_valid  (),
        .csr_funct3 (),
        .mret_valid (),


        .uses_rs1(),
        .uses_rs2(),
        .instr        (instr),
        .rs1          (rs1),
        .rs2          (rs2),
        .rd           (rd),
        .alu_op       (alu_op),
        .reg_write    (reg_write),
        .mem_read     (),
        .mem_write    (),
        .alu_src      (alu_src),
        .illegal_instr(decoded_illegal)
    );

    // Immediate extraction and sign extension.
    imm_gen u_imm_gen (
        .instr (instr),
        .imm   (immediate)
    );

    // Register file: two combinational reads, one synchronous write.
    regfile #(
        .ENABLE_WB_BYPASS(1'b0)
    ) u_regfile (
        .clk (clk),
        .we  (reg_write && !illegal_instr),
        .rs1 (rs1),
        .rs2 (rs2),
        .rd  (rd),
        .wd  (writeback_data),
        .rd1 (rs1_value),
        .rd2 (rs2_value)
    );

    // Select register operand or immediate for ALU input B.
    always_comb begin
        if (alu_src)
            alu_operand_b = immediate;
        else
            alu_operand_b = rs2_value;
    end

    // Arithmetic and logical execution.
    alu u_alu (
        .a      (rs1_value),
        .b      (alu_operand_b),
        .op     (alu_op),
        .result (result)
    );

    // Current instruction writes the ALU result back to rd.
    assign writeback_data = result;

endmodule
