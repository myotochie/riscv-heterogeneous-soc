
module pc (
    input  logic        clk,
    input  logic        reset,
    input  logic        redirect,
    input  logic [63:0] redirect_target,
    output logic [63:0] pc_value
);

    localparam logic [63:0] RESET_PC = 64'h0000_0000_8000_0000;

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_value <= RESET_PC;
        end else if (redirect) begin
            pc_value <= redirect_target;
        end else begin
            pc_value <= pc_value + 64'd4;
        end
    end

endmodule
