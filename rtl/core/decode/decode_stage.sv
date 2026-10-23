module decode_stage (
    input  logic                  clk,

    // Instructions provenant de IF/ID
    input  logic [63:0]           pc_in,
    input  logic [31:0]           instr_in,
    input  logic                  valid_in,

    // Interface de write-back vers le banc de registres
    input  logic                  wb_we,
    input  logic [4:0]            wb_rd,
    input  logic [63:0]           wb_data,

    // Signaux destinés à pipeline_id_ex
    output logic [63:0]           pc_out,
    output logic [31:0]           instr_out,
    output logic [63:0]           rs1_value_out,
    output logic [63:0]           rs2_value_out,
    output logic [63:0]           immediate_out,
    output logic [4:0]            rs1_idx_out,
    output logic [4:0]            rs2_idx_out,
    output logic [4:0]            rd_idx_out,
    output core_pkg::alu_op_t     alu_op_out,
    output logic                  reg_write_out,
    output logic                  mem_read_out,
    output logic                  alu_src_out,
    output logic                  illegal_instr_out,
    output logic                  valid_out,
    output logic                  uses_rs1_out,
    output logic                  uses_rs2_out
);

    logic [4:0]       rs1_idx;
    logic [4:0]       rs2_idx;
    logic [4:0]       rd_idx;
    core_pkg::alu_op_t alu_op;
    logic             decoded_reg_write;
    logic             decoded_mem_read;
    logic             alu_src;
    logic             decoded_illegal;
    logic             decoded_uses_rs1;
    logic             decoded_uses_rs2;
    logic [63:0]      immediate;
    logic [63:0]      rs1_value;
    logic [63:0]      rs2_value;

    // 1. Décodage de l'instruction
    decoder u_decoder (
        .instr        (instr_in),
        .rs1          (rs1_idx),
        .rs2          (rs2_idx),
        .rd           (rd_idx),
        .alu_op       (alu_op),
        .reg_write    (decoded_reg_write),
        .mem_read     (decoded_mem_read),
        .alu_src      (alu_src),
        .illegal_instr(decoded_illegal),
        .uses_rs1     (decoded_uses_rs1),
        .uses_rs2     (decoded_uses_rs2)
    );

    // 2. Génération de l'immédiat
    imm_gen u_imm_gen (
        .instr     (instr_in),
        .imm (immediate)
    );

    // 3. Banc de registres avec port d'écriture WB
    regfile u_regfile (
        .clk (clk),
        .we  (wb_we),
        .rs1 (rs1_idx),
        .rs2 (rs2_idx),
        .rd  (wb_rd),
        .wd  (wb_data),
        .rd1 (rs1_value),
        .rd2 (rs2_value)
    );

    // 4. Passage des données vers le registre ID/EX
    always_comb begin
        pc_out            = pc_in;
        instr_out         = instr_in;
        rs1_value_out     = rs1_value;
        rs2_value_out     = rs2_value;
        immediate_out     = immediate;
        rs1_idx_out       = rs1_idx;
        rs2_idx_out       = rs2_idx;
        rd_idx_out        = rd_idx;
        alu_op_out        = alu_op;
        alu_src_out       = valid_in && alu_src;
        reg_write_out     = valid_in && decoded_reg_write
                            && !decoded_illegal;
        mem_read_out      = valid_in && decoded_mem_read
                            && !decoded_illegal;
        illegal_instr_out = valid_in && decoded_illegal;
        valid_out         = valid_in;
        uses_rs1_out      = valid_in && decoded_uses_rs1;
        uses_rs2_out      = valid_in && decoded_uses_rs2;
    end

endmodule
