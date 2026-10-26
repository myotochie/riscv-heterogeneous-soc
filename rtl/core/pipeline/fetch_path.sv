module fetch_path #(
    parameter bit RAW_TEST_PROGRAM = 1'b0,
    parameter int unsigned PROGRAM_ID = 0
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall_pc,
    input  logic        stall_if_id,
    input  logic        flush,

    output logic [63:0] pc_value,
    output logic [63:0] if_id_pc,
    output logic [31:0] if_id_instr,
    output logic        if_id_valid
);

    logic [31:0] instr_mem_data;

    // Instruction memory model for integration testing.
    // PROGRAM_ID=0 preserves the legacy RAW_TEST_PROGRAM selection.
    localparam int unsigned SELECTED_PROGRAM =
        (PROGRAM_ID != 0) ? PROGRAM_ID : (RAW_TEST_PROGRAM ? 1 : 0);

    always_comb begin
        instr_mem_data = 32'h00000013; // NOP

        case (SELECTED_PROGRAM)
            0: begin
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h00500093;
                    64'h80000004: instr_mem_data = 32'h00700113;
                    64'h80000008: instr_mem_data = 32'h00900193;
                    default: ;
                endcase
            end

            1: begin
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h00500093;
                    64'h80000004: instr_mem_data = 32'h00708113;
                    64'h80000008: instr_mem_data = 32'h001101B3;
                    default: ;
                endcase
            end

            2: begin
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h00500093; // ADDI x1,x0,5
                    64'h80000004: instr_mem_data = 32'h00308093; // ADDI x1,x1,3
                    64'h80000008: instr_mem_data = 32'h00408093; // ADDI x1,x1,4
                    64'h8000000C: instr_mem_data = 32'h00108133; // ADD x2,x1,x1
                    default: ;
                endcase
            end

            3: begin
                // Load-use hazard integration program.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h0000B283; // LD x5,0(x1)
                    64'h80000004: instr_mem_data = 32'h00228333; // ADD x6,x5,x2
                    64'h80000008: instr_mem_data = 32'h00900393; // ADDI x7,x0,9
                    default: ;
                endcase
            end

            4: begin
                // End-to-end LD and load-use forwarding test.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h04000093; // ADDI x1,x0,64
                    64'h80000004: instr_mem_data = 32'h0000B283; // LD x5,0(x1)
                    64'h80000008: instr_mem_data = 32'h00528333; // ADD x6,x5,x5
                    default: ;
                endcase
            end

            5: begin
                // End-to-end SD -> LD -> ADD integration test.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h04000093; // ADDI x1,x0,64
                    64'h80000004: instr_mem_data = 32'h01500293; // ADDI x5,x0,21
                    64'h80000008: instr_mem_data = 32'h0050B023; // SD x5,0(x1)
                    64'h8000000C: instr_mem_data = 32'h0000B303; // LD x6,0(x1)
                    64'h80000010: instr_mem_data = 32'h005303B3; // ADD x7,x6,x5
                    default: ;
                endcase
            end


            default: ;
        endcase
    end

    // Program counter.
pc u_pc (
    .clk             (clk),
    .reset           (reset),
    .stall            (stall_pc),
    .redirect        (1'b0),
    .redirect_target (64'b0),
    .pc_value        (pc_value)
);	
    // Instruction Fetch / Instruction Decode register.
    pipeline_if_id u_if_id (
        .clk       (clk),
        .reset     (reset),
        .flush     (flush),
        .stall     (stall_if_id),

        .pc_in     (pc_value),
        .instr_in  (instr_mem_data),
        .valid_in  (1'b1),

        .pc_out    (if_id_pc),
        .instr_out (if_id_instr),
        .valid_out (if_id_valid)
    );

endmodule
