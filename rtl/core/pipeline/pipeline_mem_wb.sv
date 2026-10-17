
module pipeline_mem_wb (
    input  logic        clk,
    input  logic        reset,
    input  logic        flush,
    input  logic        stall,

    input  logic [63:0] pc_in,
    input  logic [31:0] instr_in,
    input  logic [63:0] alu_result_in,
    input  logic [63:0] mem_data_in,
    input  logic [4:0]  rd_idx_in,

    input  logic        reg_write_in,
    input  logic        mem_to_reg_in,
    input  logic        illegal_instr_in,
    input  logic        valid_in,

    output logic [63:0] pc_out,
    output logic [31:0] instr_out,
    output logic [63:0] alu_result_out,
    output logic [63:0] mem_data_out,
    output logic [4:0]  rd_idx_out,

    output logic        reg_write_out,
    output logic        mem_to_reg_out,
    output logic        illegal_instr_out,
    output logic        valid_out
);

    task automatic clear_register;
        begin
            pc_out            <= 64'b0;
            instr_out         <= 32'h00000013;
            alu_result_out    <= 64'b0;
            mem_data_out      <= 64'b0;
            rd_idx_out        <= 5'b0;

            reg_write_out     <= 1'b0;
            mem_to_reg_out    <= 1'b0;
            illegal_instr_out <= 1'b0;
            valid_out         <= 1'b0;
        end
    endtask

    always_ff @(posedge clk) begin
        if (reset) begin
            clear_register();
        end else if (flush) begin
            clear_register();
        end else if (!stall) begin
            pc_out            <= pc_in;
            instr_out         <= instr_in;
            alu_result_out    <= alu_result_in;
            mem_data_out      <= mem_data_in;
            rd_idx_out        <= rd_idx_in;

            reg_write_out     <= valid_in && reg_write_in;
            mem_to_reg_out    <= valid_in && mem_to_reg_in;
            illegal_instr_out <= valid_in && illegal_instr_in;
            valid_out         <= valid_in;
        end
    end

endmodule
