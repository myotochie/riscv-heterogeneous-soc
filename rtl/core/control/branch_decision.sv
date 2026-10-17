
module branch_decision (
    input  logic [2:0]  funct3,
    input  logic [63:0] rs1_value,
    input  logic [63:0] rs2_value,
    input  logic        is_branch,
    input  logic        is_jal,
    input  logic        is_jalr,
    output logic        branch_taken,
    output logic        illegal_control
);

    always_comb begin
        branch_taken   = 1'b0;
        illegal_control = 1'b0;

        if (is_jal || is_jalr) begin
            branch_taken = 1'b1;
        end else if (is_branch) begin
            case (funct3)
                3'b000: branch_taken = (rs1_value == rs2_value); // BEQ
                3'b001: branch_taken = (rs1_value != rs2_value); // BNE
                3'b100: branch_taken = ($signed(rs1_value) < $signed(rs2_value));  // BLT
                3'b101: branch_taken = ($signed(rs1_value) >= $signed(rs2_value)); // BGE
                3'b110: branch_taken = (rs1_value < rs2_value);  // BLTU
                3'b111: branch_taken = (rs1_value >= rs2_value); // BGEU
                default: begin
                    branch_taken    = 1'b0;
                    illegal_control = 1'b1;
                end
            endcase
        end
    end

endmodule
