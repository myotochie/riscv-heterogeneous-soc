module hazard_detection_unit (
    input  logic [4:0] rs1_idx_id,
    input  logic [4:0] rs2_idx_id,
    input  logic       uses_rs1_id,
    input  logic       uses_rs2_id,
    input  logic       valid_id,

    input  logic [4:0] rd_idx_ex,
    input  logic       mem_read_ex,
    input  logic       valid_ex,

    output logic       stall_pc,
    output logic       stall_if_id,
    output logic       flush_id_ex
);

    logic load_use_hazard;

    always_comb begin
        load_use_hazard =
            valid_id &&
            valid_ex &&
            mem_read_ex &&
            (rd_idx_ex != 5'd0) &&
            (
                (uses_rs1_id && (rs1_idx_id == rd_idx_ex)) ||
                (uses_rs2_id && (rs2_idx_id == rd_idx_ex))
            );

        stall_pc    = load_use_hazard;
        stall_if_id = load_use_hazard;
        flush_id_ex = load_use_hazard;
    end

endmodule
