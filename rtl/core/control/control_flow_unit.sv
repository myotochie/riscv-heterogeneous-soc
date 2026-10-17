
module control_flow_unit (
    input  logic        clk,
    input  logic        reset,
    input  logic [63:0] rs1_value,
    input  logic [63:0] rs2_value,
    input  logic [31:0] instr,
    input  logic        illegal_instr,
    input  logic        is_branch,
    input  logic        is_jal,
    input  logic        is_jalr,
    output logic [63:0] pc_value,
    output logic        control_error
);

    logic branch_taken;
    logic illegal_branch;
    logic redirect;
    logic [63:0] branch_target_value;
    logic [63:0] redirect_target;

    logic [2:0] funct3;

    assign funct3 = instr[14:12];

    branch_decision u_branch_decision (
        .funct3          (funct3),
        .rs1_value       (rs1_value),
        .rs2_value       (rs2_value),
        .is_branch       (is_branch),
        .is_jal           (is_jal),
        .is_jalr          (is_jalr),
        .branch_taken    (branch_taken),
        .illegal_control (illegal_branch)
    );

    branch_target u_branch_target (
        .pc          (pc_value),
        .instr       (instr),
        .rs1_value   (rs1_value),
        .target_kind (is_jalr ? 2'b10 : (is_jal ? 2'b01 : 2'b00)),
        .target      (branch_target_value)
    );

    control_flow u_control_flow (
        .reset            (reset),
        .illegal_instr    (illegal_instr || illegal_branch),
        .is_branch        (is_branch),
        .is_jal            (is_jal),
        .is_jalr           (is_jalr),
        .branch_taken     (branch_taken),
        .branch_target    (branch_target_value),
        .jal_target       (branch_target_value),
        .jalr_target      (branch_target_value),
        .redirect         (redirect),
        .redirect_target  (redirect_target),
        .control_error    (control_error)
    );

    pc u_pc (
        .clk             (clk),
        .reset           (reset),
        .redirect        (redirect),
        .redirect_target (redirect_target),
        .pc_value        (pc_value)
    );

endmodule
