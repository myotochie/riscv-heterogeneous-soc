
module control_flow (
    input  logic        reset,
    input  logic        illegal_instr,
    input  logic        is_branch,
    input  logic        is_jal,
    input  logic        is_jalr,
    input  logic        branch_taken,
    input  logic [63:0] branch_target,
    input  logic [63:0] jal_target,
    input  logic [63:0] jalr_target,
    output logic        redirect,
    output logic [63:0] redirect_target,
    output logic        control_error
);

    logic [2:0] transfer_count;

    always_comb begin
        transfer_count = {2'b00, is_branch}
                       + {2'b00, is_jal}
                       + {2'b00, is_jalr};

        redirect        = 1'b0;
        redirect_target = 64'b0;
        control_error   = 1'b0;

        if (transfer_count > 3'd1) begin
            control_error = 1'b1;
        end else if (!reset && !illegal_instr) begin
            if (is_jal) begin
                redirect        = 1'b1;
                redirect_target = jal_target;
            end else if (is_jalr) begin
                redirect        = 1'b1;
                redirect_target = jalr_target;
            end else if (is_branch && branch_taken) begin
                redirect        = 1'b1;
                redirect_target = branch_target;
            end
        end
    end

endmodule
