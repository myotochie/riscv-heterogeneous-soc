
module branch_target (
    input  logic [63:0] pc,
    input  logic [31:0] instr,
    input  logic [63:0] rs1_value,
    input  logic [1:0]  target_kind,
    output logic [63:0] target
);

    localparam logic [1:0] TARGET_B  = 2'b00;
    localparam logic [1:0] TARGET_J  = 2'b01;
    localparam logic [1:0] TARGET_JR = 2'b10;

    logic signed [63:0] imm_b;
    logic signed [63:0] imm_j;
    logic signed [63:0] imm_i;

    always_comb begin
        imm_b = {{51{instr[31]}},
                 instr[31],
                 instr[7],
                 instr[30:25],
                 instr[11:8],
                 1'b0};

        imm_j = {{43{instr[31]}},
                 instr[31],
                 instr[19:12],
                 instr[20],
                 instr[30:21],
                 1'b0};

        imm_i = {{52{instr[31]}}, instr[31:20]};

        case (target_kind)
            TARGET_B:  target = pc + imm_b;
            TARGET_J:  target = pc + imm_j;
            TARGET_JR: target = (rs1_value + imm_i) & 64'hFFFF_FFFF_FFFF_FFFE;
            default:   target = pc;
        endcase
    end

endmodule
