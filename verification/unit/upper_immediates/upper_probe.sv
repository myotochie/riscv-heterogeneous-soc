// Verification-only combinational composition of existing production modules.
module upper_probe (
    input logic [31:0] instr,
    input logic [63:0] pc, rs1_value, rs2_value, ex_data, wb_data,
    input logic [1:0] forward_a, forward_b,
    input logic valid, force_illegal,
    input logic [4:0] load_rd,
    output logic [63:0] immediate, result, forwarded_rs1,
    output logic [4:0] rd,
    output logic legal, uses1, uses2, write_enable, memory_read, memory_write,
    output logic hazard
);
    logic [4:0] rs1, rs2;
    core_pkg::alu_op_t op;
    logic reg_write, mem_read, mem_write, alu_src, illegal, csr;
    assign legal = !illegal;
    decoder u_decode (.instr(instr), .rs1(rs1), .rs2(rs2), .rd(rd),
        .alu_op(op), .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .alu_src(alu_src), .illegal_instr(illegal), .uses_rs1(uses1), .uses_rs2(uses2),
        .csr_valid(csr), .csr_funct3(), .mret_valid());
    imm_gen u_imm (.instr(instr), .imm(immediate));
    execute_stage #(.ENABLE_FORWARDING(1'b1)) u_execute (
        .pc_in(pc), .instr_in(instr), .rs1_value_in(rs1_value), .rs2_value_in(rs2_value),
        .immediate_in(immediate), .rd_idx_in(rd), .forward_a_in(forward_a), .forward_b_in(forward_b),
        .ex_mem_forward_data_in(ex_data), .mem_wb_forward_data_in(wb_data),
        .alu_op_in(op), .alu_src_in(alu_src), .reg_write_in(reg_write),
        .mem_read_in(mem_read), .mem_write_in(mem_write), .illegal_instr_in(illegal || force_illegal),
        .csr_valid_in(csr), .valid_in(valid), .pc_out(), .instr_out(), .alu_result_out(result),
        .forwarded_rs1_out(forwarded_rs1), .rs2_value_out(), .rd_idx_out(),
        .reg_write_out(write_enable), .mem_read_out(memory_read), .mem_write_out(memory_write),
        .mem_to_reg_out(), .illegal_instr_out(), .valid_out());
    hazard_detection_unit u_hazard (.rs1_idx_id(rs1), .rs2_idx_id(rs2),
        .uses_rs1_id(uses1), .uses_rs2_id(uses2), .valid_id(valid),
        .rd_idx_ex(load_rd), .mem_read_ex(1'b1), .valid_ex(1'b1),
        .stall_pc(hazard), .stall_if_id(), .flush_id_ex());
endmodule
