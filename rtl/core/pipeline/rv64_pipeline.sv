module rv64_pipeline #(
    parameter bit RAW_TEST_PROGRAM = 1'b0,
    parameter int unsigned PROGRAM_ID = 0,
    parameter string MEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,
    input  logic        flush,

    output logic [63:0] pc_value,

    // Observation du write-back
    output logic        wb_we,
    output logic [4:0]  wb_rd,
    output logic [63:0] wb_data,

    // Observation du registre MEM/WB
    output logic        mem_wb_valid,
    output logic [63:0] mem_wb_pc,
    output logic [31:0] mem_wb_instr
);

    logic [63:0] ex_mem_pc;
    logic [31:0] ex_mem_instr;
    logic [63:0] ex_mem_alu_result;
    logic [4:0]  ex_mem_rd_idx;
    logic        ex_mem_reg_write;
    logic        ex_mem_mem_read;
    logic        ex_mem_mem_write;
    logic [63:0] ex_mem_rs2_value;
    logic        ex_mem_mem_to_reg;
    logic        ex_mem_illegal_instr;
    logic        ex_mem_valid;

    logic [63:0] mem_wb_alu_result;
    logic [63:0] mem_wb_mem_data;
    logic [4:0]  mem_wb_rd_idx;
    logic        mem_wb_reg_write;
    logic        mem_wb_mem_to_reg;
    logic        mem_wb_illegal_instr;

    logic        wb_we_internal;

    // MEM stage signals.
    logic [63:0] mem_read_data;
    logic        mem_access_fault;

    fetch_decode_execute_path #(
        .RAW_TEST_PROGRAM(RAW_TEST_PROGRAM),
        .PROGRAM_ID(PROGRAM_ID)
    ) u_frontend (
        .clk                 (clk),
        .reset               (reset),
        .stall               (stall),
        .flush               (flush),

        .wb_we               (wb_we),
        .wb_rd               (wb_rd),
        .wb_data             (wb_data),

        .mem_wb_valid        (mem_wb_valid),
        .mem_wb_reg_write    (mem_wb_reg_write),
        .mem_wb_rd_idx       (mem_wb_rd_idx),

        .pc_value            (pc_value),
        .ex_mem_pc           (ex_mem_pc),
        .ex_mem_instr        (ex_mem_instr),
        .ex_mem_alu_result   (ex_mem_alu_result),
        .ex_mem_rd_idx       (ex_mem_rd_idx),
        .ex_mem_reg_write    (ex_mem_reg_write),
        .ex_mem_mem_read     (ex_mem_mem_read),
        .ex_mem_mem_write  (ex_mem_mem_write),
        .ex_mem_rs2_value  (ex_mem_rs2_value),
        .ex_mem_mem_to_reg   (ex_mem_mem_to_reg),
        .ex_mem_illegal_instr(ex_mem_illegal_instr),
        .ex_mem_valid        (ex_mem_valid)
    );

    // MEM stage: 64-bit data memory.
    data_memory #(
        .INIT_FILE(MEM_INIT_FILE)
    ) u_data_memory (
        .clk          (clk),
        .reset        (reset),
        .mem_read     (ex_mem_valid && ex_mem_mem_read),
        .mem_write    (ex_mem_valid && ex_mem_mem_write && !stall && !flush),
        .address      (ex_mem_alu_result),
        .write_data   (ex_mem_rs2_value),
        .read_data    (mem_read_data),
        .access_fault (mem_access_fault)
    );

    pipeline_mem_wb u_mem_wb (
        .clk               (clk),
        .reset             (reset),
        .flush             (flush),
        .stall             (stall),

        .pc_in             (ex_mem_pc),
        .instr_in          (ex_mem_instr),
        .alu_result_in     (ex_mem_alu_result),
        .mem_data_in       (mem_read_data),
        .rd_idx_in         (ex_mem_rd_idx),

        .reg_write_in      (ex_mem_reg_write),
        .mem_to_reg_in     (ex_mem_mem_to_reg),
        .illegal_instr_in  (ex_mem_illegal_instr),
        .valid_in          (ex_mem_valid),

        .pc_out            (mem_wb_pc),
        .instr_out         (mem_wb_instr),
        .alu_result_out    (mem_wb_alu_result),
        .mem_data_out      (mem_wb_mem_data),
        .rd_idx_out        (mem_wb_rd_idx),
        .reg_write_out     (mem_wb_reg_write),
        .mem_to_reg_out    (mem_wb_mem_to_reg),
        .illegal_instr_out (mem_wb_illegal_instr),
        .valid_out         (mem_wb_valid)
    );

    writeback_stage u_writeback (
        .alu_result_in     (mem_wb_alu_result),
        .mem_data_in       (mem_wb_mem_data),
        .rd_idx_in         (mem_wb_rd_idx),
        .reg_write_in      (mem_wb_reg_write),
        .mem_to_reg_in     (mem_wb_mem_to_reg),
        .illegal_instr_in  (mem_wb_illegal_instr),
        .valid_in          (mem_wb_valid),
        .stall             (stall),

        .wb_we             (wb_we_internal),
        .wb_rd             (wb_rd),
        .wb_data           (wb_data)
    );

    // Empêche toute écriture pendant reset ou flush.
    assign wb_we = wb_we_internal && !reset && !flush;



endmodule
