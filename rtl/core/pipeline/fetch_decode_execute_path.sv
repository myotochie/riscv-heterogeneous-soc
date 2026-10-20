module fetch_decode_execute_path (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,
    input  logic        flush,

    input  logic        wb_we,
    input  logic [4:0]  wb_rd,
    input  logic [63:0] wb_data,

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

    fetch_decode_path u_fetch_decode (
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

    execute_stage u_execute (
        .pc_in             (id_ex_pc),
        .instr_in          (id_ex_instr),
        .rs1_value_in     (id_ex_rs1_value),
        .rs2_value_in     (id_ex_rs2_value),
        .immediate_in      (id_ex_immediate),
        .rd_idx_in         (id_ex_rd_idx),
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
