module fetch_decode_execute_path #(
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

    // Informations MEM/WB pour le forwarding
    input  logic        mem_wb_valid,
    input  logic        mem_wb_reg_write,
    input  logic [4:0]  mem_wb_rd_idx,

    output logic [63:0] pc_value,
    output logic [63:0] ex_mem_pc,
    output logic [31:0] ex_mem_instr,
    output logic [63:0] ex_mem_alu_result,
    output logic [4:0]  ex_mem_rd_idx,
    output logic        ex_mem_reg_write,
    output logic        ex_mem_illegal_instr,
    output logic        ex_mem_valid
);

    logic [63:0] if_id_pc;
    logic [31:0] if_id_instr;
    logic        if_id_valid;

    logic [63:0] id_ex_pc;
    logic [31:0] id_ex_instr;
    logic [63:0] id_ex_rs1_value;
    logic [63:0] id_ex_rs2_value;
    logic [63:0] id_ex_immediate;
    logic [4:0]  id_ex_rs1_idx;
    logic [4:0]  id_ex_rs2_idx;
    logic [4:0]  id_ex_rd_idx;
    core_pkg::alu_op_t id_ex_alu_op;
    logic id_ex_reg_write;
    logic id_ex_alu_src;
    logic id_ex_illegal_instr;
    logic id_ex_valid;

    logic [63:0] ex_pc;
    logic [31:0] ex_instr;
    logic [63:0] ex_alu_result;
    logic [63:0] ex_rs2_value;
    logic [4:0]  ex_rd_idx;
    logic ex_reg_write;
    logic ex_mem_read;
    logic ex_mem_write;
    logic ex_mem_to_reg;
    logic ex_illegal_instr;
    logic ex_valid;

    logic [63:0] unused_ex_mem_rs2_value;
    logic unused_ex_mem_read;
    logic unused_ex_mem_write;
    logic unused_ex_mem_to_reg;


    // Forwarding control
    logic [1:0] forward_a;
    logic [1:0] forward_b;

    forwarding_unit u_forwarding_unit (
        .rs1_idx_ex       (id_ex_rs1_idx),
        .rs2_idx_ex       (id_ex_rs2_idx),

        .rd_idx_ex_mem    (ex_mem_rd_idx),
        .reg_write_ex_mem (ex_mem_reg_write),
        .valid_ex_mem     (ex_mem_valid),

        .rd_idx_mem_wb    (mem_wb_rd_idx),
        .reg_write_mem_wb (mem_wb_reg_write),
        .valid_mem_wb     (mem_wb_valid),

        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

    fetch_decode_path #(
        .RAW_TEST_PROGRAM(RAW_TEST_PROGRAM),
        .PROGRAM_ID(PROGRAM_ID)
    ) u_fetch_decode (
        .clk                 (clk),
        .reset               (reset),
        .stall               (stall),
        .flush               (flush),
        .wb_we               (wb_we),
        .wb_rd               (wb_rd),
        .wb_data             (wb_data),
        .pc_value            (pc_value),
        .if_id_pc            (if_id_pc),
        .if_id_instr         (if_id_instr),
        .if_id_valid         (if_id_valid),
        .id_ex_pc            (id_ex_pc),
        .id_ex_instr         (id_ex_instr),
        .id_ex_rs1_value     (id_ex_rs1_value),
        .id_ex_rs2_value     (id_ex_rs2_value),
        .id_ex_immediate     (id_ex_immediate),
        .id_ex_rs1_idx      (id_ex_rs1_idx),
        .id_ex_rs2_idx      (id_ex_rs2_idx),
        .id_ex_rd_idx       (id_ex_rd_idx),
        .id_ex_alu_op       (id_ex_alu_op),
        .id_ex_reg_write    (id_ex_reg_write),
        .id_ex_alu_src      (id_ex_alu_src),
        .id_ex_illegal_instr(id_ex_illegal_instr),
        .id_ex_valid        (id_ex_valid)
    );

    execute_stage #(
        .ENABLE_FORWARDING(1'b1)
    ) u_execute (
        .pc_in             (id_ex_pc),
        .instr_in          (id_ex_instr),
        .rs1_value_in     (id_ex_rs1_value),
        .rs2_value_in     (id_ex_rs2_value),
        .immediate_in      (id_ex_immediate),
        .rd_idx_in         (id_ex_rd_idx),
        .forward_a_in      (forward_a),
        .forward_b_in      (forward_b),
        .ex_mem_forward_data_in (ex_mem_alu_result),
        .mem_wb_forward_data_in (wb_data),
        .alu_op_in         (id_ex_alu_op),
        .alu_src_in        (id_ex_alu_src),
        .reg_write_in      (id_ex_reg_write),
        .illegal_instr_in  (id_ex_illegal_instr),
        .valid_in          (id_ex_valid),
        .pc_out            (ex_pc),
        .instr_out         (ex_instr),
        .alu_result_out    (ex_alu_result),
        .rs2_value_out     (ex_rs2_value),
        .rd_idx_out        (ex_rd_idx),
        .reg_write_out     (ex_reg_write),
        .mem_read_out      (ex_mem_read),
        .mem_write_out     (ex_mem_write),
        .mem_to_reg_out    (ex_mem_to_reg),
        .illegal_instr_out (ex_illegal_instr),
        .valid_out         (ex_valid)
    );

    pipeline_ex_mem u_ex_mem (
        .clk               (clk),
        .reset             (reset),
        .flush             (flush),
        .stall             (stall),
        .pc_in             (ex_pc),
        .instr_in          (ex_instr),
        .alu_result_in     (ex_alu_result),
        .rs2_value_in      (ex_rs2_value),
        .rd_idx_in         (ex_rd_idx),
        .reg_write_in      (ex_reg_write),
        .mem_read_in       (ex_mem_read),
        .mem_write_in      (ex_mem_write),
        .mem_to_reg_in     (ex_mem_to_reg),
        .illegal_instr_in  (ex_illegal_instr),
        .valid_in          (ex_valid),
        .pc_out            (ex_mem_pc),
        .instr_out         (ex_mem_instr),
        .alu_result_out    (ex_mem_alu_result),
        .rs2_value_out     (unused_ex_mem_rs2_value),
        .rd_idx_out        (ex_mem_rd_idx),
        .reg_write_out     (ex_mem_reg_write),
        .mem_read_out      (unused_ex_mem_read),
        .mem_write_out     (unused_ex_mem_write),
        .mem_to_reg_out    (unused_ex_mem_to_reg),
        .illegal_instr_out (ex_mem_illegal_instr),
        .valid_out         (ex_mem_valid)
    );

endmodule
