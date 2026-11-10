
module pipeline_ex_mem (
    input  logic        clk,
    input  logic        reset,
    input  logic        flush,
    input  logic        stall,

    input  logic [63:0] pc_in,
    input  logic [31:0] instr_in,
    input  logic [63:0] alu_result_in,
    input  logic [63:0] rs2_value_in,
    input  logic [4:0]  rd_idx_in,

    input  logic        reg_write_in,
    input  logic        mem_read_in,
    input  logic        mem_write_in,
    input  logic        mem_to_reg_in,
    input  logic        illegal_instr_in,
    input  logic        valid_in,
    input  logic        target_misaligned_in,
    input  logic [63:0] control_target_in,
    input  logic        csr_valid_in,
    input  logic [2:0]  csr_funct3_in,
    input  logic        mret_valid_in,
    input  logic [11:0] csr_addr_in,
    input  logic [63:0] csr_new_value_in,
    input  logic [63:0] csr_read_result_in,
    input  logic        csr_write_enable_in,

    output logic [63:0] pc_out,
    output logic [31:0] instr_out,
    output logic [63:0] alu_result_out,
    output logic [63:0] rs2_value_out,
    output logic [4:0]  rd_idx_out,

    output logic        reg_write_out,
    output logic        mem_read_out,
    output logic        mem_write_out,
    output logic        mem_to_reg_out,
    output logic        illegal_instr_out,
    output logic        valid_out,
    output logic        target_misaligned_out,
    output logic [63:0] control_target_out,
    output logic        csr_valid_out,
    output logic [2:0]  csr_funct3_out,
    output logic        mret_valid_out,
    output logic [11:0] csr_addr_out,
    output logic [63:0] csr_new_value_out,
    output logic [63:0] csr_read_result_out,
    output logic        csr_write_enable_out
);

    task automatic clear_register;
        begin
            pc_out            <= 64'b0;
            instr_out         <= 32'h00000013;
            alu_result_out    <= 64'b0;
            rs2_value_out     <= 64'b0;
            rd_idx_out        <= 5'b0;

            reg_write_out     <= 1'b0;
            mem_read_out      <= 1'b0;
            mem_write_out     <= 1'b0;
            mem_to_reg_out    <= 1'b0;
            illegal_instr_out <= 1'b0;
            valid_out         <= 1'b0;
            target_misaligned_out <= 1'b0;
            control_target_out <= 64'b0;
            csr_valid_out     <= 1'b0;
            csr_funct3_out    <= 3'b000;
            mret_valid_out    <= 1'b0;
            csr_addr_out <= 12'b0;
            csr_new_value_out <= 64'b0;
            csr_read_result_out <= 64'b0;
            csr_write_enable_out <= 1'b0;
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
            rs2_value_out     <= rs2_value_in;
            rd_idx_out        <= rd_idx_in;

            reg_write_out     <= valid_in && reg_write_in;
            mem_read_out      <= valid_in && mem_read_in;
            mem_write_out     <= valid_in && mem_write_in;
            mem_to_reg_out    <= valid_in && mem_to_reg_in;
            illegal_instr_out <= valid_in && illegal_instr_in;
            valid_out         <= valid_in;
            target_misaligned_out <= valid_in && target_misaligned_in;
            control_target_out <= control_target_in;
            csr_valid_out     <= valid_in && csr_valid_in;
            csr_funct3_out    <= csr_funct3_in;
            mret_valid_out    <= valid_in && mret_valid_in;
            csr_addr_out <= csr_addr_in;
            csr_new_value_out <= csr_new_value_in;
            csr_read_result_out <= csr_read_result_in;
            csr_write_enable_out <=
                valid_in && csr_valid_in && csr_write_enable_in;
        end
    end

endmodule
