
module pipeline_if_id (
    input  logic        clk,
    input  logic        reset,
    input  logic        flush,
    input  logic        stall,

    input  logic [63:0] pc_in,
    input  logic [31:0] instr_in,
    input  logic        valid_in,

    output logic [63:0] pc_out,
    output logic [31:0] instr_out,
    output logic        valid_out
);

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_out    <= 64'b0;
            instr_out <= 32'h00000013; // NOP: ADDI x0, x0, 0
            valid_out <= 1'b0;
        end else if (flush) begin
            pc_out    <= 64'b0;
            instr_out <= 32'h00000013;
            valid_out <= 1'b0;
        end else if (!stall) begin
            pc_out    <= pc_in;
            instr_out <= instr_in;
            valid_out <= valid_in;
        end
    end

endmodule
