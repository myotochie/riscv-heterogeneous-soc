
module imm_gen (
    input  logic [31:0] instr,
    output logic [63:0] imm
);

    // ADDI: sign-extend the 12-bit immediate to 64 bits.
    always_comb begin
        imm = {{52{instr[31]}}, instr[31:20]};
    end

endmodule
