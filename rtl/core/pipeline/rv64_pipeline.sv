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
    output logic [31:0] mem_wb_instr,

    // Exception observation interface (verification only).
    output logic        trap_valid_o,
    output logic [63:0] trap_epc_o,
    output logic [63:0] trap_cause_o,
    output logic [63:0] trap_tval_o,

    // CSR architectural state observation (verification).
    output logic [63:0] csr_mtvec_o,
    output logic [63:0] csr_mepc_o,
    output logic [63:0] csr_mcause_o,
    output logic [63:0] csr_mtval_o,
    output logic [63:0] csr_mstatus_o
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
    logic        ex_mem_target_misaligned;
    logic [63:0] ex_mem_control_target;
    logic        ex_mem_csr_valid;
    logic [2:0]  ex_mem_csr_funct3;
    logic        ex_mem_mret_valid;
    logic [11:0] ex_mem_csr_addr;
    logic [63:0] ex_mem_csr_new_value;
    logic [63:0] ex_mem_csr_read_result;
    logic ex_mem_csr_write_enable;

    logic        mem_wb_csr_valid;
    logic [2:0]  mem_wb_csr_funct3;
    logic        mem_wb_mret_valid;
    logic [11:0] mem_wb_csr_addr;
    logic [63:0] mem_wb_csr_new_value;
    logic [63:0] mem_wb_csr_read_result;
    logic mem_wb_csr_write_enable;

    logic [63:0] mem_wb_alu_result;
    logic [63:0] mem_wb_mem_data;
    logic [4:0]  mem_wb_rd_idx;
    logic        mem_wb_reg_write;
    logic        mem_wb_mem_to_reg;
    logic        mem_wb_illegal_instr;
    logic        mem_wb_mem_fault;

    logic        wb_we_internal;

    // CSR architectural commit at WB.
    logic        csr_commit_we;
    logic [63:0] trap_mtvec_effective;

    // A retiring MRET is older than instructions in MEM/EX.
    logic        mret_retire;
    logic        trap_take;
    logic        redirect_valid;
    logic [63:0] redirect_target;


    // MEM stage signals.
    logic [63:0] mem_read_data;
    logic        mem_access_fault;
    logic        mem_misaligned_fault;
    logic        mem_out_of_range_fault;

    // Memory exception detection and trap redirection.
    logic        trap_valid;
    logic [63:0] trap_target;
    logic [63:0] trap_epc;
    logic [63:0] trap_cause;
    logic [63:0] trap_tval;

    // Machine-mode CSR state.
    logic [63:0] csr_mtvec;
    logic [63:0] csr_mepc;
    logic [63:0] csr_mcause;
    logic [63:0] csr_mtval;
    logic [63:0] csr_mstatus;
    logic [63:0] csr_read_data;
    logic [11:0] csr_read_addr;
    logic [63:0] ex_csr_new_value;
    logic [63:0] ex_csr_read_result;
    logic        ex_csr_write_enable;

    exception_controller u_exception_controller (
        .reset                  (reset),
        .stall                  (stall),
        .mem_valid              (ex_mem_valid && !flush),
        .mem_target_misaligned  (ex_mem_target_misaligned),
        .mem_control_target     (ex_mem_control_target),
        .mem_read               (ex_mem_mem_read),
        .mem_write              (ex_mem_mem_write),
        .mem_misaligned_fault   (mem_misaligned_fault),
        .mem_out_of_range_fault (mem_out_of_range_fault),
        .mem_pc                 (ex_mem_pc),
        .mem_address            (ex_mem_alu_result),
        .mtvec                  (trap_mtvec_effective),
        .trap_valid             (trap_valid),
        .trap_target            (trap_target),
        .trap_epc               (trap_epc),
        .trap_cause             (trap_cause),
        .trap_tval              (trap_tval)
    );


    // Machine-mode CSR register file.
    // CSR retirement and architectural MRET connection.
    csr_file u_csr_file (
        .clk         (clk),
        .reset       (reset),

        .trap_valid  (trap_take),
        .trap_epc    (trap_epc),
        .trap_cause  (trap_cause),
        .trap_tval   (trap_tval),

        .csr_we      (csr_commit_we),
        .csr_raddr   (csr_read_addr),
        .csr_waddr   (mem_wb_csr_addr),
        .csr_wdata   (mem_wb_csr_new_value),
        .csr_rdata   (csr_read_data),

        .mret_valid  (mret_retire),

        .mtvec_o     (csr_mtvec),
        .mepc_o      (csr_mepc),
        .mcause_o    (csr_mcause),
        .mtval_o     (csr_mtval),
        .mstatus_o   (csr_mstatus)
    );

    fetch_decode_execute_path #(
        .RAW_TEST_PROGRAM(RAW_TEST_PROGRAM),
        .PROGRAM_ID(PROGRAM_ID)
    ) u_frontend (
        .clk                 (clk),
        .reset               (reset),
        .stall               (stall),
        .flush               (flush),
        .trap_redirect    (redirect_valid),
        .trap_target      (redirect_target),
        .trap_flush_young (redirect_valid),

        .wb_we               (wb_we),
        .wb_rd               (wb_rd),
        .wb_data             (wb_data),
        .csr_read_data       (csr_read_data),
        .mem_wb_csr_addr         (mem_wb_csr_addr),
        .mem_wb_csr_new_value    (mem_wb_csr_new_value),
        .mem_wb_csr_write_pending(csr_commit_we),
        .csr_read_addr       (csr_read_addr),
        .ex_csr_new_value    (ex_csr_new_value),
        .ex_csr_read_result  (ex_csr_read_result),
        .ex_csr_write_enable (ex_csr_write_enable),

        .mem_wb_valid        (mem_wb_valid),
        .mem_wb_reg_write    (mem_wb_reg_write && !mem_wb_mem_fault),
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
        .ex_mem_valid        (ex_mem_valid),
        .ex_mem_target_misaligned(ex_mem_target_misaligned),
        .ex_mem_control_target(ex_mem_control_target),
        .ex_mem_csr_valid    (ex_mem_csr_valid),
        .ex_mem_csr_funct3   (ex_mem_csr_funct3),
        .ex_mem_mret_valid   (ex_mem_mret_valid),
        .ex_mem_csr_addr(ex_mem_csr_addr),
        .ex_mem_csr_new_value(ex_mem_csr_new_value),
        .ex_mem_csr_read_result(ex_mem_csr_read_result),
        .ex_mem_csr_write_enable(ex_mem_csr_write_enable)
    );

    // MEM stage: 64-bit data memory.
    data_memory #(
        .INIT_FILE(MEM_INIT_FILE)
    ) u_data_memory (
        .clk          (clk),
        .reset        (reset),
        .mem_read     (ex_mem_valid && ex_mem_mem_read && !mret_retire),
        .mem_write    (ex_mem_valid && ex_mem_mem_write
                   && !stall && !flush && !mret_retire),
        .address      (ex_mem_alu_result),
        .write_data   (ex_mem_rs2_value),
        .read_data    (mem_read_data),
        .access_fault      (mem_access_fault),
        .misaligned_fault  (mem_misaligned_fault),
        .out_of_range_fault(mem_out_of_range_fault)
    );

    pipeline_mem_wb u_mem_wb (
        .clk               (clk),
        .reset             (reset),
        .flush             (flush || redirect_valid),
        .stall             (stall),

        .pc_in             (ex_mem_pc),
        .instr_in          (ex_mem_instr),
        .alu_result_in     (ex_mem_alu_result),
        .mem_data_in       (mem_read_data),
        .rd_idx_in         (ex_mem_rd_idx),

        .reg_write_in      (ex_mem_reg_write),
        .mem_to_reg_in     (ex_mem_mem_to_reg),
        .illegal_instr_in  (ex_mem_illegal_instr),
        .mem_fault_in      (mem_access_fault),
        .valid_in          (ex_mem_valid),
        .csr_valid_in      (ex_mem_csr_valid),
        .csr_funct3_in     (ex_mem_csr_funct3),
        .mret_valid_in     (ex_mem_mret_valid),
        .csr_addr_in(ex_mem_csr_addr),
        .csr_new_value_in(ex_mem_csr_new_value),
        .csr_read_result_in(ex_mem_csr_read_result),
        .csr_write_enable_in(ex_mem_csr_write_enable),

        .pc_out            (mem_wb_pc),
        .instr_out         (mem_wb_instr),
        .alu_result_out    (mem_wb_alu_result),
        .mem_data_out      (mem_wb_mem_data),
        .rd_idx_out        (mem_wb_rd_idx),
        .reg_write_out     (mem_wb_reg_write),
        .mem_to_reg_out    (mem_wb_mem_to_reg),
        .illegal_instr_out (mem_wb_illegal_instr),
        .mem_fault_out     (mem_wb_mem_fault),
        .valid_out         (mem_wb_valid),
        .csr_valid_out     (mem_wb_csr_valid),
        .csr_funct3_out    (mem_wb_csr_funct3),
        .mret_valid_out    (mem_wb_mret_valid),
        .csr_addr_out(mem_wb_csr_addr),
        .csr_new_value_out(mem_wb_csr_new_value),
        .csr_read_result_out(mem_wb_csr_read_result),
        .csr_write_enable_out(mem_wb_csr_write_enable)
    );

    writeback_stage u_writeback (
        .alu_result_in     (mem_wb_alu_result),
          .mem_data_in       (mem_wb_mem_data),
          .csr_read_result_in(mem_wb_csr_read_result),
        .rd_idx_in         (mem_wb_rd_idx),
        .reg_write_in      (mem_wb_reg_write),
          .mem_to_reg_in     (mem_wb_mem_to_reg),
          .csr_valid_in     (mem_wb_csr_valid),
        .illegal_instr_in  (mem_wb_illegal_instr),
        .mem_fault_in      (mem_wb_mem_fault),
        .valid_in          (mem_wb_valid),
        .stall             (stall),

        .wb_we             (wb_we_internal),
        .wb_rd             (wb_rd),
        .wb_data           (wb_data)
    );

    // Architectural retirement of MRET in WB.
    assign mret_retire =
        mem_wb_valid
        && mem_wb_mret_valid
        && !mem_wb_illegal_instr
        && !mem_wb_mem_fault
        && !reset
        && !stall
        && !flush;

    // The WB MRET is older than the MEM fault.
    assign trap_take = trap_valid && !mret_retire;

    // Architectural PC redirect arbitration.
    assign redirect_valid = mret_retire || trap_take;
    assign redirect_target =
        mret_retire ? csr_mepc : trap_target;

    // Combinational trap event observation.
    assign trap_valid_o = trap_take;
    assign trap_epc_o   = trap_epc;
    assign trap_cause_o = trap_cause;
    assign trap_tval_o  = trap_tval;

    // CSR observation outputs.
    assign csr_mtvec_o   = csr_mtvec;
    assign csr_mepc_o    = csr_mepc;
    assign csr_mcause_o  = csr_mcause;
    assign csr_mtval_o   = csr_mtval;
    assign csr_mstatus_o = csr_mstatus;

    // The trap target must use the architectural mtvec value
    // after retirement of an older WB instruction.
    // csr_commit_we is independent of trap_valid.
    assign trap_mtvec_effective =
        (csr_commit_we && mem_wb_csr_addr == 12'h305)
        ? {mem_wb_csr_new_value[63:2], 2'b00}
        : csr_mtvec;

    // CSR commit: only valid, non-faulting instructions may write.
    assign csr_commit_we =
        mem_wb_valid
        && mem_wb_csr_valid
        && mem_wb_csr_write_enable
        && !mem_wb_illegal_instr
        && !mem_wb_mem_fault
        && !reset
        && !stall
        && !flush;

    // Empêche toute écriture GPR pendant reset ou flush.
    assign wb_we = wb_we_internal && !reset && !flush;



endmodule
