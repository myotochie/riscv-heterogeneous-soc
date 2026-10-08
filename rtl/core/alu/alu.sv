module alu (
    input  logic [63:0] a,
    input  logic [63:0] b,
    input  core_pkg::alu_op_t op,
    output logic [63:0] result
);

    always_comb begin
        unique case (op)
            core_pkg::ALU_ADD:  result = a + b;
            core_pkg::ALU_SUB:  result = a - b;
            core_pkg::ALU_AND:  result = a & b;
            core_pkg::ALU_OR:   result = a | b;
            core_pkg::ALU_XOR:  result = a ^ b;
            core_pkg::ALU_SLL:  result = a << b[5:0];
            core_pkg::ALU_SRL:  result = a >> b[5:0];
            core_pkg::ALU_SRA:  result = $signed(a) >>> b[5:0];
            core_pkg::ALU_SLT:  result = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0;
            core_pkg::ALU_SLTU: result = (a < b) ? 64'd1 : 64'd0;
            default:            result = 64'd0;
        endcase
    end

endmodule
