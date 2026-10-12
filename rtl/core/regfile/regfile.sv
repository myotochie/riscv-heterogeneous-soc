
module regfile (
    input  logic        clk,
    input  logic        we,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [63:0] wd,
    output logic [63:0] rd1,
    output logic [63:0] rd2
);

    logic [63:0] regs [1:31];

    // Combinational read port 1.
    always_comb begin
        if (rs1 == 5'd0)
            rd1 = 64'd0;
        else
            rd1 = regs[rs1];
    end

    // Combinational read port 2.
    always_comb begin
        if (rs2 == 5'd0)
            rd2 = 64'd0;
        else
            rd2 = regs[rs2];
    end

    // Synchronous write port.
    always_ff @(posedge clk) begin
        if (we && (rd != 5'd0))
            regs[rd] <= wd;
    end

endmodule
