
module imm_gen (
    input  logic [31:0] instr,
    output logic [63:0] imm
);

    // RV64I immediate generation.
    // I-type: ADDI, LD.
    // S-type: SD.
    always_comb begin
        case (instr[6:0])
            7'b0100011: begin
                // S-type immediate.
                imm = {{52{instr[31]}},
                       instr[31:25],
                       instr[11:7]};
            end

            default: begin
                // I-type immediate.
                imm = {{52{instr[31]}},
                       instr[31:20]};
            end
        endcase
    end

endmodule
