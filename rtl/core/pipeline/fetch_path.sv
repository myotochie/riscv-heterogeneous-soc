module fetch_path #(
    parameter bit RAW_TEST_PROGRAM = 1'b0
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,
    input  logic        flush,

    output logic [63:0] pc_value,
    output logic [63:0] if_id_pc,
    output logic [31:0] if_id_instr,
    output logic        if_id_valid
);

    logic [31:0] instr_mem_data;

    // Instruction memory model for integration testing.
    always_comb begin
        case (pc_value)
            64'h0000000080000000:
                instr_mem_data = 32'h00500093; // ADDI x1, x0, 5

            64'h0000000080000004:
                instr_mem_data = RAW_TEST_PROGRAM
                    ? 32'h00708113  // ADDI x2, x1, 7
                    : 32'h00700113; // ADDI x2, x0, 7

            64'h0000000080000008:
                instr_mem_data = RAW_TEST_PROGRAM
                    ? 32'h001101B3  // ADD x3, x2, x1
                    : 32'h00900193; // ADDI x3, x0, 9

            default:
                instr_mem_data = 32'h00000013; // NOP
        endcase
    end

    // Program counter.
pc u_pc (
    .clk             (clk),
    .reset           (reset),
    .stall            (stall),
    .redirect        (1'b0),
    .redirect_target (64'b0),
    .pc_value        (pc_value)
);	
    // Instruction Fetch / Instruction Decode register.
    pipeline_if_id u_if_id (
        .clk       (clk),
        .reset     (reset),
        .flush     (flush),
        .stall     (stall),

        .pc_in     (pc_value),
        .instr_in  (instr_mem_data),
        .valid_in  (1'b1),

        .pc_out    (if_id_pc),
        .instr_out (if_id_instr),
        .valid_out (if_id_valid)
    );

endmodule
