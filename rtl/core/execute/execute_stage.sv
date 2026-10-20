module execute_stage (
    input  logic [63:0]       pc_in,
    input  logic [31:0]       instr_in,
    input  logic [63:0]       rs1_value_in,
    input  logic [63:0]       rs2_value_in,
    input  logic [63:0]       immediate_in,
    input  logic [4:0]        rd_idx_in,

    input  core_pkg::alu_op_t alu_op_in,
    input  logic              alu_src_in,
    input  logic              reg_write_in,
    input  logic              illegal_instr_in,
    input  logic              valid_in,

    output logic [63:0]       pc_out,
    output logic [31:0]       instr_out,
    output logic [63:0]       alu_result_out,
    output logic [63:0]       rs2_value_out,
    output logic [4:0]        rd_idx_out,

    output logic              reg_write_out,
    output logic              mem_read_out,
    output logic              mem_write_out,
    output logic              mem_to_reg_out,
    output logic              illegal_instr_out,
    output logic              valid_out
);

    logic [63:0] alu_operand_b;
    logic [63:0] alu_result;

    assign alu_operand_b = alu_src_in
                         ? immediate_in
                         : rs2_value_in;

    alu u_alu (
        .a      (rs1_value_in),
        .b      (alu_operand_b),
        .op     (alu_op_in),
        .result (alu_result)
    );

    always_comb begin
        pc_out            = pc_in;
        instr_out         = instr_in;
        alu_result_out    = alu_result;
        rs2_value_out     = rs2_value_in;
        rd_idx_out        = rd_idx_in;

        reg_write_out     = valid_in && reg_write_in
                            && !illegal_instr_in;

        mem_read_out      = 1'b0;
        mem_write_out     = 1'b0;
        mem_to_reg_out    = 1'b0;

        illegal_instr_out = valid_in && illegal_instr_in;
        valid_out         = valid_in;
    end

endmodule
