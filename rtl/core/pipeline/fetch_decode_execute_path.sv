module fetch_decode_execute_path #(
    parameter bit RAW_TEST_PROGRAM = 1'b0,
    parameter int unsigned PROGRAM_ID = 0
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,
    input  logic        flush,

    input  logic        trap_redirect,
    input  logic [63:0] trap_target,
    input  logic        trap_flush_young,

    input  logic        wb_we,
    input  logic [4:0]  wb_rd,
    input  logic [63:0] wb_data,

    input  logic [63:0] csr_read_data,
    input  logic [11:0] mem_wb_csr_addr,
    input  logic [63:0] mem_wb_csr_new_value,
    input  logic        mem_wb_csr_write_pending,

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
    output logic        ex_mem_mem_read,
    output logic        ex_mem_mem_write,
    output logic [63:0] ex_mem_rs2_value,
    output logic        ex_mem_mem_to_reg,
    output logic        ex_mem_illegal_instr,
    output logic        ex_mem_valid,
    output logic        ex_mem_csr_valid,
    output logic [2:0]  ex_mem_csr_funct3,
    output logic        ex_mem_mret_valid,
    output logic [11:0] ex_mem_csr_addr,
    output logic [63:0] ex_mem_csr_new_value,
    output logic [63:0] ex_mem_csr_read_result,
    output logic        ex_mem_csr_write_enable,

    output logic [11:0] csr_read_addr,
    output logic [63:0] ex_csr_new_value,
    output logic [63:0] ex_csr_read_result,
    output logic        ex_csr_write_enable
);

    logic [63:0] if_id_pc;
    logic [31:0] if_id_instr;
    logic        if_id_valid;

    // Source usage information from the ID stage.
    // Reserved for the load-use hazard detection unit.
    logic        dec_uses_rs1;
    logic        dec_uses_rs2;

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
    logic       id_ex_csr_valid;
    logic [2:0] id_ex_csr_funct3;
    logic       id_ex_mret_valid;

    logic [63:0] ex_pc;
    logic [31:0] ex_instr;
    logic [63:0] ex_alu_result;
    logic [63:0] ex_forwarded_rs1;
    logic [63:0] csr_new_value_raw;
    logic [63:0] csr_read_result_raw;
    logic        csr_write_enable_raw;
    logic [63:0] ex_rs2_value;
    logic [4:0]  ex_rd_idx;
    logic ex_reg_write;
    logic ex_mem_read;
    logic ex_mem_write;
    logic ex_mem_to_reg;
    logic ex_illegal_instr;
    logic ex_valid;
    logic ex_csr_valid;
    logic [2:0] ex_csr_funct3;
    logic ex_mret_valid;

    // CF-02: conditional branches resolved in EX.
    logic ex_branch_taken;
    logic ex_branch_illegal;
    logic ex_branch_redirect;
    logic [63:0] ex_branch_target;
    logic unused_ex_mem_read;
    logic unused_ex_mem_to_reg;


    // Local load-use hazard controls.
    logic hazard_stall_pc;
    logic hazard_stall_if_id;
    logic hazard_flush_id_ex;

    // Registered memory-read control from the EX stage.
    logic id_ex_mem_read;
    logic id_ex_mem_write;

    hazard_detection_unit u_hazard_detection (
        .rs1_idx_id    (if_id_instr[19:15]),
        .rs2_idx_id    (if_id_instr[24:20]),
        .uses_rs1_id   (dec_uses_rs1),
        .uses_rs2_id   (dec_uses_rs2),
        .valid_id      (if_id_valid),
        .rd_idx_ex     (id_ex_rd_idx),
        .mem_read_ex   (id_ex_mem_read),
        .valid_ex      (id_ex_valid),
        .stall_pc      (hazard_stall_pc),
        .stall_if_id   (hazard_stall_if_id),
        .flush_id_ex   (hazard_flush_id_ex)
    );


    // CSR-to-GPR forwarding.
    // CSR instructions return the old CSR value to rd.
    // ALU instructions return the ALU result.
    logic [63:0] ex_mem_gpr_forward_data;

    assign ex_mem_gpr_forward_data =
        (ex_mem_valid
         && ex_mem_csr_valid
         && ex_mem_reg_write
         && !ex_mem_illegal_instr)
        ? ex_mem_csr_read_result
        : ex_mem_alu_result;

    // Forwarding control
    logic [1:0] forward_a;
    logic [1:0] forward_b;

    forwarding_unit u_forwarding_unit (
        .rs1_idx_ex       (id_ex_rs1_idx),
        .rs2_idx_ex       (id_ex_rs2_idx),

        .rd_idx_ex_mem    (ex_mem_rd_idx),
        .reg_write_ex_mem (ex_mem_reg_write),
        .mem_read_ex_mem  (ex_mem_mem_read),
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
        .flush               (flush || trap_flush_young || ex_branch_redirect),
        .trap_redirect (trap_redirect || ex_branch_redirect),
        .trap_target   (trap_redirect ? trap_target : ex_branch_target),
        .hazard_stall_pc     (hazard_stall_pc),
        .hazard_stall_if_id  (hazard_stall_if_id),
        .hazard_flush_id_ex  (hazard_flush_id_ex),
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
        .id_ex_mem_read   (id_ex_mem_read),
        .id_ex_mem_write  (id_ex_mem_write),
        .id_ex_alu_src      (id_ex_alu_src),
        .id_ex_illegal_instr(id_ex_illegal_instr),
        .id_ex_valid        (id_ex_valid),
        .dec_uses_rs1       (dec_uses_rs1),
        .dec_uses_rs2       (dec_uses_rs2),
        .id_ex_csr_valid    (id_ex_csr_valid),
        .id_ex_csr_funct3   (id_ex_csr_funct3),
        .id_ex_mret_valid   (id_ex_mret_valid)
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
        .ex_mem_forward_data_in (ex_mem_gpr_forward_data),
        .mem_wb_forward_data_in (wb_data),
        .alu_op_in         (id_ex_alu_op),
        .alu_src_in        (id_ex_alu_src),
        .mem_read_in (id_ex_mem_read),
        .mem_write_in    (id_ex_mem_write),
        .reg_write_in      (id_ex_reg_write),
        .illegal_instr_in  (id_ex_illegal_instr),
          .csr_valid_in     (id_ex_csr_valid),
        .valid_in          (id_ex_valid),
        .pc_out            (ex_pc),
        .instr_out         (ex_instr),
        .alu_result_out    (ex_alu_result),
        .forwarded_rs1_out (ex_forwarded_rs1),
        .rs2_value_out     (ex_rs2_value),
        .rd_idx_out        (ex_rd_idx),
        .reg_write_out     (ex_reg_write),
        .mem_read_out      (ex_mem_read),
        .mem_write_out     (ex_mem_write),
        .mem_to_reg_out    (ex_mem_to_reg),
        .illegal_instr_out (ex_illegal_instr),
        .valid_out         (ex_valid)
    );

    // Combinational CSR read address for the EX-stage instruction.
    assign csr_read_addr = id_ex_instr[31:20];

    // CSR RAW forwarding:
    // EX/MEM is newer than MEM/WB.
    // Both paths bypass writes that have not yet reached csr_file.
    logic [63:0] csr_old_value_effective;

    assign csr_old_value_effective =
        (ex_mem_valid
         && ex_mem_csr_valid
         && ex_mem_csr_write_enable
         && !ex_mem_illegal_instr
         && (ex_mem_csr_addr == csr_read_addr))
        ? ex_mem_csr_new_value
        : ((mem_wb_csr_write_pending
            && (mem_wb_csr_addr == csr_read_addr))
           ? mem_wb_csr_new_value
           : csr_read_data);


    csr_execute u_csr_execute (
        .funct3            (id_ex_csr_funct3),
        .rs1_idx           (id_ex_rs1_idx),
        .rs1_value         (ex_forwarded_rs1),
        .csr_old_value     (csr_old_value_effective),
        .csr_new_value     (csr_new_value_raw),
        .csr_write_enable  (csr_write_enable_raw),
        .csr_read_result   (csr_read_result_raw)
    );

    // Validity gating: no CSR side effects are enabled here.
    assign ex_csr_new_value = csr_new_value_raw;
    assign ex_csr_read_result = csr_read_result_raw;
    assign ex_csr_write_enable =
        ex_valid && id_ex_csr_valid &&
        !ex_illegal_instr && csr_write_enable_raw;

    // CSR metadata propagation only: no architectural side effects.
    assign ex_csr_valid  = ex_valid && id_ex_csr_valid
                           && !ex_illegal_instr;
    assign ex_csr_funct3 = id_ex_csr_funct3;
    assign ex_mret_valid = ex_valid && id_ex_mret_valid
                           && !ex_illegal_instr;

    // Compare the forwarded operands, not stale ID-stage values.
    branch_decision u_ex_branch_decision (
        .funct3          (id_ex_instr[14:12]),
        .rs1_value       (ex_forwarded_rs1),
        .rs2_value       (ex_rs2_value),
        .is_branch       (id_ex_valid &&
                          id_ex_instr[6:0] == 7'b1100011 &&
                          !id_ex_illegal_instr),
        .is_jal          (1'b0),
        .is_jalr         (1'b0),
        .branch_taken    (ex_branch_taken),
        .illegal_control (ex_branch_illegal)
    );

    branch_target u_ex_branch_target (
        .pc          (id_ex_pc),
        .instr       (id_ex_instr),
        .rs1_value   (ex_forwarded_rs1),
        .target_kind (2'b00),
        .target      (ex_branch_target)
    );

    // A branch in EX is younger than WB MRET and MEM traps.
    // External stall/flush must also suppress the redirect.
    assign ex_branch_redirect =
        ex_branch_taken &&
        !ex_branch_illegal &&
        !stall &&
        !flush &&
        !trap_redirect &&
        !trap_flush_young;

    pipeline_ex_mem u_ex_mem (
        .clk               (clk),
        .reset             (reset),
        .flush             (flush || trap_flush_young),
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
        .csr_valid_in      (ex_csr_valid),
        .csr_funct3_in     (ex_csr_funct3),
        .mret_valid_in     (ex_mret_valid),
        .csr_addr_in(csr_read_addr),
        .csr_new_value_in(ex_csr_new_value),
        .csr_read_result_in(ex_csr_read_result),
        .csr_write_enable_in(ex_csr_write_enable),
        .pc_out            (ex_mem_pc),
        .instr_out         (ex_mem_instr),
        .alu_result_out    (ex_mem_alu_result),
        .rs2_value_out     (ex_mem_rs2_value),
        .rd_idx_out        (ex_mem_rd_idx),
        .reg_write_out     (ex_mem_reg_write),
        .mem_read_out      (ex_mem_mem_read),
        .mem_write_out     (ex_mem_mem_write),
        .mem_to_reg_out    (ex_mem_mem_to_reg),
        .illegal_instr_out (ex_mem_illegal_instr),
        .valid_out         (ex_mem_valid),
        .csr_valid_out     (ex_mem_csr_valid),
        .csr_funct3_out    (ex_mem_csr_funct3),
        .mret_valid_out    (ex_mem_mret_valid),
        .csr_addr_out(ex_mem_csr_addr),
        .csr_new_value_out(ex_mem_csr_new_value),
        .csr_read_result_out(ex_mem_csr_read_result),
        .csr_write_enable_out(ex_mem_csr_write_enable)
    );



endmodule
