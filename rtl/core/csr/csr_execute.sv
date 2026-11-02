module csr_execute (
    input  logic [2:0]  funct3,
    input  logic [4:0]  rs1_idx,
    input  logic [63:0] rs1_value,
    input  logic [63:0] csr_old_value,

    output logic [63:0] csr_new_value,
    output logic        csr_write_enable,
    output logic [63:0] csr_read_result
);

    logic [63:0] operand;

    always_comb begin
        operand = funct3[2]
                ? {59'b0, rs1_idx}
                : rs1_value;

        csr_new_value    = csr_old_value;
        csr_read_result  = csr_old_value;
        csr_write_enable = 1'b0;

        case (funct3)
            3'b001, 3'b101: begin
                // CSRRW / CSRRWI
                csr_new_value    = operand;
                csr_write_enable = 1'b1;
            end

            3'b010, 3'b110: begin
                // CSRRS / CSRRSI
                csr_new_value    = csr_old_value | operand;
                csr_write_enable = (rs1_idx != 5'd0);
            end

            3'b011, 3'b111: begin
                // CSRRC / CSRRCI
                csr_new_value    = csr_old_value & ~operand;
                csr_write_enable = (rs1_idx != 5'd0);
            end

            default: begin
                csr_new_value    = csr_old_value;
                csr_write_enable = 1'b0;
            end
        endcase
    end

endmodule
