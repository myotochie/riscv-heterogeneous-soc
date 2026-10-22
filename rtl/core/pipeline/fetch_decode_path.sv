module fetch_decode_path #(
    parameter bit RAW_TEST_PROGRAM = 1'b0,
    parameter int unsigned PROGRAM_ID = 0
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,
    input  logic        flush,

    input  logic        wb_we,
    input  logic [4:0]  wb_rd,
    input  logic [63:0] wb_data,

    output logic [63:0] pc_value,
    output logic [63:0] if_id_pc,
    output logic [31:0] if_id_instr,
    output logic        if_id_valid,

    output logic [63:0] id_ex_pc,
    output logic [31:0] id_ex_instr,
    output logic [63:0] id_ex_rs1_value,
    output logic [63:0] id_ex_rs2_value,
    output logic [63:0] id_ex_immediate,
    output logic [4:0]  id_ex_rs1_idx,
    output logic [4:0]  id_ex_rs2_idx,
    output logic [4:0]  id_ex_rd_idx,
    output core_pkg::alu_op_t id_ex_alu_op,
    output logic        id_ex_reg_write,
    output logic        id_ex_alu_src,
    output logic        id_ex_illegal_instr,
    output logic        id_ex_valid
);

    logic [63:0] dec_pc;
    logic [31:0] dec_instr;
    logic [63:0] dec_rs1_value;
    logic [63:0] dec_rs2_value;
    logic [63:0] dec_immediate;
    logic [4:0]  dec_rs1_idx;
    logic [4:0]  dec_rs2_idx;
    logic [4:0]  dec_rd_idx;
    core_pkg::alu_op_t dec_alu_op;
    logic dec_reg_write;
    logic dec_alu_src;
    logic dec_illegal_instr;
    logic dec_valid;

    fetch_path #(
        .RAW_TEST_PROGRAM(RAW_TEST_PROGRAM),
        .PROGRAM_ID(PROGRAM_ID)
    ) u_fetch (
        .clk         (clk),
        .reset       (reset),
        .stall       (stall),
        .flush       (flush),
        .pc_value    (pc_value),
        .if_id_pc    (if_id_pc),
        .if_id_instr (if_id_instr),
        .if_id_valid (if_id_valid)
    );

    decode_stage u_decode (
        .clk               (clk),
        .pc_in             (if_id_pc),
        .instr_in          (if_id_instr),
        .valid_in          (if_id_valid),
        .wb_we             (wb_we),
        .wb_rd             (wb_rd),
        .wb_data           (wb_data),
        .pc_out            (dec_pc),
        .instr_out         (dec_instr),
        .rs1_value_out     (dec_rs1_value),
        .rs2_value_out     (dec_rs2_value),
        .immediate_out     (dec_immediate),
        .rs1_idx_out       (dec_rs1_idx),
        .rs2_idx_out       (dec_rs2_idx),
        .rd_idx_out        (dec_rd_idx),
        .alu_op_out        (dec_alu_op),
        .reg_write_out     (dec_reg_write),
        .alu_src_out       (dec_alu_src),
        .illegal_instr_out (dec_illegal_instr),
        .valid_out         (dec_valid)
    );

    pipeline_id_ex u_id_ex (
        .clk               (clk),
        .reset             (reset),
        .flush             (flush),
        .stall             (stall),

        .pc_in             (dec_pc),
        .instr_in          (dec_instr),
        .rs1_value_in     (dec_rs1_value),
        .rs2_value_in     (dec_rs2_value),
        .immediate_in      (dec_immediate),
        .rs1_idx_in        (dec_rs1_idx),
        .rs2_idx_in        (dec_rs2_idx),
        .rd_idx_in         (dec_rd_idx),
        .alu_op_in         (dec_alu_op),
        .reg_write_in      (dec_reg_write),
        .alu_src_in        (dec_alu_src),
        .illegal_instr_in  (dec_illegal_instr),
        .valid_in          (dec_valid),

        .pc_out            (id_ex_pc),
        .instr_out         (id_ex_instr),
        .rs1_value_out     (id_ex_rs1_value),
        .rs2_value_out     (id_ex_rs2_value),
        .immediate_out     (id_ex_immediate),
        .rs1_idx_out       (id_ex_rs1_idx),
        .rs2_idx_out       (id_ex_rs2_idx),
        .rd_idx_out        (id_ex_rd_idx),
        .alu_op_out        (id_ex_alu_op),
        .reg_write_out     (id_ex_reg_write),
        .alu_src_out       (id_ex_alu_src),
        .illegal_instr_out (id_ex_illegal_instr),
        .valid_out         (id_ex_valid)
    );

endmodule
