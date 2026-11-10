module execute_stage #(
    parameter bit ENABLE_FORWARDING = 1'b0
) (
    input  logic [63:0]       pc_in,
    input  logic [31:0]       instr_in,
    input  logic [63:0]       rs1_value_in,
    input  logic [63:0]       rs2_value_in,
    input  logic [63:0]       immediate_in,
    input  logic [4:0]        rd_idx_in,

    input  logic [1:0]        forward_a_in,
    input  logic [1:0]        forward_b_in,
    input  logic [63:0]       ex_mem_forward_data_in,
    input  logic [63:0]       mem_wb_forward_data_in,

    input  core_pkg::alu_op_t alu_op_in,
    input  logic              alu_src_in,
    input  logic              reg_write_in,
    input  logic              mem_read_in,
    input  logic              mem_write_in,
    input  logic              illegal_instr_in,
    input  logic              csr_valid_in,
    input  logic              valid_in,

    output logic [63:0]       pc_out,
    output logic [31:0]       instr_out,
    output logic [63:0]       alu_result_out,
    output logic [63:0]       forwarded_rs1_out,
    output logic [63:0]       rs2_value_out,
    output logic [4:0]        rd_idx_out,

    output logic              reg_write_out,
    output logic              mem_read_out,
    output logic              mem_write_out,
    output logic              mem_to_reg_out,
    output logic              illegal_instr_out,
    output logic              valid_out
);

    logic [63:0] forwarded_rs1;
    logic [63:0] forwarded_rs2;
    logic [63:0] alu_operand_b;
    logic [63:0] alu_result;
    logic is_jump;

    // Carry the link through the ordinary ALU-result WB/forwarding path.
    assign is_jump = (instr_in[6:0] == 7'b1101111) ||
                     (instr_in[6:0] == 7'b1100111 &&
                      instr_in[14:12] == 3'b000);

    generate
        if (ENABLE_FORWARDING) begin : gen_forwarding
            forwarding_mux u_forward_a (
                .original_data  (rs1_value_in),
                .ex_mem_data    (ex_mem_forward_data_in),
                .mem_wb_data    (mem_wb_forward_data_in),
                .forward_sel    (forward_a_in),
                .forwarded_data (forwarded_rs1)
            );

            forwarding_mux u_forward_b (
                .original_data  (rs2_value_in),
                .ex_mem_data    (ex_mem_forward_data_in),
                .mem_wb_data    (mem_wb_forward_data_in),
                .forward_sel    (forward_b_in),
                .forwarded_data (forwarded_rs2)
            );
        end else begin : gen_no_forwarding
            assign forwarded_rs1 = rs1_value_in;
            assign forwarded_rs2 = rs2_value_in;
        end
    endgenerate

    assign forwarded_rs1_out = forwarded_rs1;

    assign alu_operand_b = alu_src_in
                         ? immediate_in
                         : forwarded_rs2;

    alu u_alu (
        .a      (forwarded_rs1),
        .b      (alu_operand_b),
        .op     (alu_op_in),
        .result (alu_result)
    );

    always_comb begin
        pc_out            = pc_in;
        instr_out         = instr_in;
        alu_result_out    = is_jump ? pc_in + 64'd4 : alu_result;
        rs2_value_out     = forwarded_rs2;
        rd_idx_out        = rd_idx_in;

        // A valid CSR instruction writes its old CSR value to rd.
        // The WB stage selects csr_read_result instead of ALU data.
        reg_write_out     = valid_in && !illegal_instr_in
                            && (reg_write_in || csr_valid_in);

        mem_read_out      = valid_in && mem_read_in
                            && !illegal_instr_in;
        mem_write_out     = valid_in && mem_write_in
                             && !illegal_instr_in;
        mem_to_reg_out    = valid_in && mem_read_in
                            && !illegal_instr_in;

        illegal_instr_out = valid_in && illegal_instr_in;
        valid_out         = valid_in;
    end

endmodule
