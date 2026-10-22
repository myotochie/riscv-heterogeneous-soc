module forwarding_mux (
    input  logic [63:0] original_data,
    input  logic [63:0] ex_mem_data,
    input  logic [63:0] mem_wb_data,
    input  logic [1:0]  forward_sel,

    output logic [63:0] forwarded_data
);

    always_comb begin
        case (forward_sel)
            2'b00: forwarded_data = original_data;
            2'b01: forwarded_data = mem_wb_data;
            2'b10: forwarded_data = ex_mem_data;
            default: forwarded_data = original_data;
        endcase
    end

endmodule
