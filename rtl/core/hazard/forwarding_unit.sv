module forwarding_unit (
    input  logic [4:0] rs1_idx_ex,
    input  logic [4:0] rs2_idx_ex,

    input  logic [4:0] rd_idx_ex_mem,
    input  logic       reg_write_ex_mem,
    input  logic       mem_read_ex_mem,
    input  logic       valid_ex_mem,

    input  logic [4:0] rd_idx_mem_wb,
    input  logic       reg_write_mem_wb,
    input  logic       valid_mem_wb,

    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    always_comb begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        // MEM/WB forwarding
        if (valid_mem_wb && reg_write_mem_wb &&
            rd_idx_mem_wb != 5'd0) begin

            if (rd_idx_mem_wb == rs1_idx_ex)
                forward_a = 2'b01;

            if (rd_idx_mem_wb == rs2_idx_ex)
                forward_b = 2'b01;
        end

        // EX/MEM forwarding has higher priority
        if (valid_ex_mem && reg_write_ex_mem &&
            !mem_read_ex_mem &&
              rd_idx_ex_mem != 5'd0) begin

            if (rd_idx_ex_mem == rs1_idx_ex)
                forward_a = 2'b10;

            if (rd_idx_ex_mem == rs2_idx_ex)
                forward_b = 2'b10;
        end
    end

endmodule
