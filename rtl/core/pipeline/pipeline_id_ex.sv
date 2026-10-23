
module pipeline_id_ex (
    input  logic                 clk,
    input  logic                 reset,
    input  logic                 flush,
    input  logic                 stall,

    input  logic [63:0]          pc_in,
    input  logic [31:0]          instr_in,
    input  logic [63:0]          rs1_value_in,
    input  logic [63:0]          rs2_value_in,
    input  logic [63:0]          immediate_in,

    input  logic [4:0]           rs1_idx_in,
    input  logic [4:0]           rs2_idx_in,
    input  logic [4:0]           rd_idx_in,

    input  core_pkg::alu_op_t    alu_op_in,
    input  logic                 reg_write_in,
    input  logic                 mem_read_in,
    input  logic                 alu_src_in,
    input  logic                 illegal_instr_in,
    input  logic                 valid_in,

    output logic [63:0]          pc_out,
    output logic [31:0]          instr_out,
    output logic [63:0]          rs1_value_out,
    output logic [63:0]          rs2_value_out,
    output logic [63:0]          immediate_out,

    output logic [4:0]           rs1_idx_out,
    output logic [4:0]           rs2_idx_out,
    output logic [4:0]           rd_idx_out,

    output core_pkg::alu_op_t    alu_op_out,
    output logic                 reg_write_out,
    output logic                 mem_read_out,
    output logic                 alu_src_out,
    output logic                 illegal_instr_out,
    output logic                 valid_out
);

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_out            <= 64'b0;
            instr_out         <= 32'h00000013;
            rs1_value_out     <= 64'b0;
            rs2_value_out     <= 64'b0;
            immediate_out     <= 64'b0;

            rs1_idx_out       <= 5'b0;
            rs2_idx_out       <= 5'b0;
            rd_idx_out        <= 5'b0;

            alu_op_out        <= core_pkg::ALU_ADD;
            reg_write_out     <= 1'b0;
            mem_read_out      <= 1'b0;
            alu_src_out       <= 1'b0;
            illegal_instr_out <= 1'b0;
            valid_out         <= 1'b0;
        end else if (flush) begin
            pc_out            <= 64'b0;
            instr_out         <= 32'h00000013;
            rs1_value_out     <= 64'b0;
            rs2_value_out     <= 64'b0;
            immediate_out     <= 64'b0;

            rs1_idx_out       <= 5'b0;
            rs2_idx_out       <= 5'b0;
            rd_idx_out        <= 5'b0;

            alu_op_out        <= core_pkg::ALU_ADD;
            reg_write_out     <= 1'b0;
            mem_read_out      <= 1'b0;
            alu_src_out       <= 1'b0;
            illegal_instr_out <= 1'b0;
            valid_out         <= 1'b0;
        end else if (!stall) begin
            pc_out            <= pc_in;
            instr_out         <= instr_in;
            rs1_value_out     <= rs1_value_in;
            rs2_value_out     <= rs2_value_in;
            immediate_out     <= immediate_in;

            rs1_idx_out       <= rs1_idx_in;
            rs2_idx_out       <= rs2_idx_in;
            rd_idx_out        <= rd_idx_in;

            alu_op_out        <= alu_op_in;
            reg_write_out     <= valid_in && reg_write_in;
            mem_read_out      <= valid_in && mem_read_in;
            alu_src_out       <= alu_src_in;
            illegal_instr_out <= valid_in && illegal_instr_in;
            valid_out         <= valid_in;
       end
    end

endmodule
