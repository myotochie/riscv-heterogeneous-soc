module writeback_stage (
    input  logic [63:0] alu_result_in,
    input  logic [63:0] mem_data_in,
    input  logic [4:0]  rd_idx_in,

    input  logic        reg_write_in,
    input  logic        mem_to_reg_in,
    input  logic        illegal_instr_in,
    input  logic        mem_fault_in,
    input  logic        valid_in,
    input  logic        stall,

    output logic        wb_we,
    output logic [4:0]  wb_rd,
    output logic [63:0] wb_data
);

    always_comb begin
        wb_data = mem_to_reg_in ? mem_data_in : alu_result_in;
        wb_rd   = rd_idx_in;

        wb_we = valid_in
                && reg_write_in
                && !illegal_instr_in
                && !mem_fault_in
                && !stall
                && (rd_idx_in != 5'd0);
    end

endmodule
