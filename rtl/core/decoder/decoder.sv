
module decoder (
    input  logic [31:0] instr,

    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,

    output core_pkg::alu_op_t alu_op,
    output logic              reg_write,
    output logic              alu_src,
    output logic              illegal_instr
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    always_comb begin
        // Safe defaults: unsupported instructions do not write registers.
        alu_op        = core_pkg::ALU_ADD;
        reg_write     = 1'b0;
        alu_src       = 1'b0;
        illegal_instr = 1'b1;

        // R-type integer register-register operations.
        if (opcode == 7'b0110011) begin
            unique case (funct3)
                3'b000: begin
                    if (funct7 == 7'b0000000) begin
                        alu_op        = core_pkg::ALU_ADD;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end else if (funct7 == 7'b0100000) begin
                        alu_op        = core_pkg::ALU_SUB;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end
                end

                3'b001: begin
                    if (funct7 == 7'b0000000) begin
                        alu_op        = core_pkg::ALU_SLL;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end
                end

                3'b010: begin
                    if (funct7 == 7'b0000000) begin
                        alu_op        = core_pkg::ALU_SLT;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end
                end

                3'b011: begin
                    if (funct7 == 7'b0000000) begin
                        alu_op        = core_pkg::ALU_SLTU;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end
                end

                3'b100: begin
                    if (funct7 == 7'b0000000) begin
                        alu_op        = core_pkg::ALU_XOR;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end
                end

                3'b101: begin
                    if (funct7 == 7'b0000000) begin
                        alu_op        = core_pkg::ALU_SRL;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end else if (funct7 == 7'b0100000) begin
                        alu_op        = core_pkg::ALU_SRA;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end
                end

                3'b110: begin
                    if (funct7 == 7'b0000000) begin
                        alu_op        = core_pkg::ALU_OR;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end
                end

                3'b111: begin
                    if (funct7 == 7'b0000000) begin
                        alu_op        = core_pkg::ALU_AND;
                        reg_write     = 1'b1;
                        illegal_instr = 1'b0;
                    end
                end

                default: begin
                    // Safe defaults already indicate an illegal instruction.
                end
            endcase

        // I-type arithmetic: initially ADDI only.
        end else if (opcode == 7'b0010011) begin
            if (funct3 == 3'b000) begin
                alu_op        = core_pkg::ALU_ADD;
                reg_write     = 1'b1;
                alu_src       = 1'b1;
                illegal_instr = 1'b0;
            end
        end
    end

endmodule
