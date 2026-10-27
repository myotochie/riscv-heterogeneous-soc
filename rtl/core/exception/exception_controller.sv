module exception_controller (
    input  logic        reset,
    input  logic        stall,

    input  logic        mem_valid,
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic        mem_misaligned_fault,
    input  logic        mem_out_of_range_fault,

    input  logic [63:0] mem_pc,
    input  logic [63:0] mem_address,

    output logic        trap_valid,
    output logic [63:0] trap_target,
    output logic [63:0] trap_epc,
    output logic [63:0] trap_cause,
    output logic [63:0] trap_tval
);

    localparam logic [63:0] TRAP_VECTOR = 64'h0000000080000100;

    always_comb begin
        trap_valid  = 1'b0;
        trap_target = TRAP_VECTOR;
        trap_epc    = 64'b0;
        trap_cause  = 64'b0;
        trap_tval   = 64'b0;

        if (!reset && !stall && mem_valid &&
            (mem_read || mem_write) &&
            (mem_misaligned_fault || mem_out_of_range_fault)) begin

            trap_valid = 1'b1;
            trap_epc   = mem_pc;
            trap_tval  = mem_address;

            if (mem_read) begin
                trap_cause = mem_misaligned_fault ? 64'd4 : 64'd5;
            end else begin
                trap_cause = mem_misaligned_fault ? 64'd6 : 64'd7;
            end
        end
    end

endmodule
