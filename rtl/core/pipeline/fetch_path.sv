module fetch_path #(
    parameter bit RAW_TEST_PROGRAM = 1'b0,
    parameter int unsigned PROGRAM_ID = 0
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall_pc,
    input  logic        stall_if_id,
    input  logic        flush,

    // Architectural PC redirection (trap/exception).
    input  logic        trap_redirect,
    input  logic [63:0] trap_target,

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


            6: begin
                // Positive and negative LD/SD offset integration test.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h05000093; // ADDI x1,x0,80
                    64'h80000004: instr_mem_data = 32'h02A00293; // ADDI x5,x0,42
                    64'h80000008: instr_mem_data = 32'h0050B423; // SD x5,8(x1)
                    64'h8000000C: instr_mem_data = 32'hFE50BC23; // SD x5,-8(x1)
                    64'h80000010: instr_mem_data = 32'h0080B303; // LD x6,8(x1)
                    64'h80000014: instr_mem_data = 32'hFF80B383; // LD x7,-8(x1)
                    64'h80000018: instr_mem_data = 32'h00730433; // ADD x8,x6,x7
                    default: ;
                endcase
            end

            7: begin
                // Full-width 64-bit LD -> SD -> LD integration test.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h04000093; // ADDI x1,x0,64
                    64'h80000004: instr_mem_data = 32'h0000B283; // LD x5,0(x1)
                    64'h80000008: instr_mem_data = 32'h0050B423; // SD x5,8(x1)
                    64'h8000000C: instr_mem_data = 32'h0080B303; // LD x6,8(x1)
                    default: ;
                endcase
            end

            8: begin
                // Invalid unaligned LD must not update x5.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h04100093; // ADDI x1,x0,65
                    64'h80000004: instr_mem_data = 32'h06300293; // ADDI x5,x0,99
                    64'h80000008: instr_mem_data = 32'h0000B283; // LD x5,0(x1)
                    64'h8000000C: instr_mem_data = 32'h00700313; // ADDI x6,x0,7
                    default: ;
                endcase
            end

            9: begin
                // Dependency immediately after an invalid LD.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h04100093; // ADDI x1,x0,65
                    64'h80000004: instr_mem_data = 32'h06300293; // ADDI x5,x0,99
                    64'h80000008: instr_mem_data = 32'h0000B283; // LD x5,0(x1)
                    64'h8000000C: instr_mem_data = 32'h00028333; // ADD x6,x5,x0
                    64'h80000010: instr_mem_data = 32'h00700393; // ADDI x7,x0,7
                    default: ;
                endcase
            end

            10: begin
                // Precise trap test: misaligned LD and trap handler.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h04100093; // ADDI x1,x0,65
                    64'h80000004: instr_mem_data = 32'h06300293; // ADDI x5,x0,99
                    64'h80000008: instr_mem_data = 32'h0000B283; // LD x5,0(x1)
                    64'h8000000C: instr_mem_data = 32'h02A00313; // ADDI x6,x0,42
                    64'h80000010: instr_mem_data = 32'h00700393; // ADDI x7,x0,7

                    // Exception handler.
                    64'h80000100: instr_mem_data = 32'h07B00513; // ADDI x10,x0,123
                    default: ;
                endcase
            end


            11: begin
                // Out-of-range memory access at address 0x1000.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h40000093; // ADDI x1,x0,1024
                    64'h80000004: instr_mem_data = 32'h40008093; // ADDI x1,x1,1024
                    64'h80000008: instr_mem_data = 32'h40008093; // ADDI x1,x1,1024
                    64'h8000000C: instr_mem_data = 32'h40008093; // ADDI x1,x1,1024
                    64'h80000010: instr_mem_data = 32'h06300293; // ADDI x5,x0,99
                    64'h80000014: instr_mem_data = 32'h0000B303; // LD x6,0(x1)
                    64'h80000018: instr_mem_data = 32'h02A00393; // ADDI x7,x0,42
                    64'h8000001C: instr_mem_data = 32'h00800413; // ADDI x8,x0,8
                    64'h80000100: instr_mem_data = 32'h07B00513; // ADDI x10,x0,123
                    default: ;
                endcase
            end

            12: begin
                // Store address misaligned: address 0x41.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h04100093; // ADDI x1,x0,65
                    64'h80000004: instr_mem_data = 32'h06300293; // ADDI x5,x0,99
                    64'h80000008: instr_mem_data = 32'h0050B023; // SD x5,0(x1)
                    64'h8000000C: instr_mem_data = 32'h02A00393; // ADDI x7,x0,42
                    64'h80000010: instr_mem_data = 32'h00800413; // ADDI x8,x0,8
                    64'h80000100: instr_mem_data = 32'h07B00513; // ADDI x10,x0,123
                    default: ;
                endcase
            end

            13: begin
                // Out-of-range memory access at address 0x1000.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h40000093; // ADDI x1,x0,1024
                    64'h80000004: instr_mem_data = 32'h40008093; // ADDI x1,x1,1024
                    64'h80000008: instr_mem_data = 32'h40008093; // ADDI x1,x1,1024
                    64'h8000000C: instr_mem_data = 32'h40008093; // ADDI x1,x1,1024
                    64'h80000010: instr_mem_data = 32'h06300293; // ADDI x5,x0,99
                    64'h80000014: instr_mem_data = 32'h0050B023; // SD x5,0(x1)
                    64'h80000018: instr_mem_data = 32'h02A00393; // ADDI x7,x0,42
                    64'h8000001C: instr_mem_data = 32'h00800413; // ADDI x8,x0,8
                    64'h80000100: instr_mem_data = 32'h07B00513; // ADDI x10,x0,123
                    default: ;
                endcase
            end

            14: begin
                // CSR architectural commit integration.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h20000093; // ADDI x1,x0,512
                    64'h80000004: instr_mem_data = 32'h00000013; // NOP
                    64'h80000008: instr_mem_data = 32'h00000013; // NOP
                    64'h8000000C: instr_mem_data = 32'h30509073; // CSRRW x0,mtvec,x1
                    64'h80000010: instr_mem_data = 32'h00000013; // NOP
                    64'h80000014: instr_mem_data = 32'h00000013; // NOP
                    default: ;
                endcase
            end

            15: begin
                // CSRRW returns the old mtvec in x5 and writes x1.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h20000093; // ADDI x1,x0,512
                    64'h80000004: instr_mem_data = 32'h00000013; // NOP
                    64'h80000008: instr_mem_data = 32'h00000013; // NOP
                    64'h8000000C: instr_mem_data = 32'h305092F3; // CSRRW x5,mtvec,x1
                    64'h80000010: instr_mem_data = 32'h00000013; // NOP
                    64'h80000014: instr_mem_data = 32'h00000013; // NOP
                    64'h80000018: instr_mem_data = 32'h00000013; // NOP
                    64'h8000001C: instr_mem_data = 32'h00700313; // ADDI x6,x0,7
                    default: ;
                endcase
            end

            16: begin
                // Back-to-back CSR RAW dependency test.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h20000093; // ADDI x1,x0,512
                    64'h80000004: instr_mem_data = 32'h00000013; // NOP
                    64'h80000008: instr_mem_data = 32'h00000013; // NOP
                    64'h8000000C: instr_mem_data = 32'h305092F3; // CSRRW x5,mtvec,x1
                    64'h80000010: instr_mem_data = 32'h30502373; // CSRRS x6,mtvec,x0
                    64'h80000014: instr_mem_data = 32'h00000013; // NOP
                    64'h80000018: instr_mem_data = 32'h00000013; // NOP
                    64'h8000001C: instr_mem_data = 32'h00700393; // ADDI x7,x0,7
                    default: ;
                endcase
            end

            17: begin
                // CSR forwarding priority: EX/MEM over MEM/WB.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h10000093; // ADDI x1,x0,256
                    64'h80000004: instr_mem_data = 32'h20000113; // ADDI x2,x0,512
                    64'h80000008: instr_mem_data = 32'h00000013; // NOP
                    64'h8000000C: instr_mem_data = 32'h00000013; // NOP
                    64'h80000010: instr_mem_data = 32'h30509073; // CSRRW x0,mtvec,x1
                    64'h80000014: instr_mem_data = 32'h30511073; // CSRRW x0,mtvec,x2
                    64'h80000018: instr_mem_data = 32'h30502373; // CSRRS x6,mtvec,x0
                    64'h8000001C: instr_mem_data = 32'h00000013; // NOP
                    64'h80000020: instr_mem_data = 32'h00700393; // ADDI x7,x0,7
                    default: ;
                endcase
            end

            18: begin
                // CSR-to-ALU RAW hazard: no NOP between CSRRS and ADDI.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h305022F3; // CSRRS x5,mtvec,x0
                    64'h80000004: instr_mem_data = 32'h00428313; // ADDI x6,x5,4
                    64'h80000008: instr_mem_data = 32'h00700393; // ADDI x7,x0,7
                    default: ;
                endcase
            end

            19: begin
                // CSR-to-ALU dependency with one intervening NOP.
                // Intended to exercise the MEM/WB forwarding path.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h305022F3; // CSRRS x5,mtvec,x0
                    64'h80000004: instr_mem_data = 32'h00000013; // NOP
                    64'h80000008: instr_mem_data = 32'h00428313; // ADDI x6,x5,4
                    64'h8000000C: instr_mem_data = 32'h00700393; // ADDI x7,x0,7
                    default: ;
                endcase
            end

            20: begin
                // Precise trap: older CSR in WB, younger fault in MEM.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h20000093; // ADDI x1,x0,512
                    64'h80000004: instr_mem_data = 32'h04100113; // ADDI x2,x0,65
                    64'h80000008: instr_mem_data = 32'h00000013; // NOP
                    64'h8000000C: instr_mem_data = 32'h00000013; // NOP
                    64'h80000010: instr_mem_data = 32'h30509073; // CSRRW x0,mtvec,x1
                    64'h80000014: instr_mem_data = 32'h00013303; // LD x6,0(x2)
                    64'h80000018: instr_mem_data = 32'h00700393; // ADDI x7,x0,7

                    // New expected trap handler.
                    64'h00000200: instr_mem_data = 32'h07B00513; // ADDI x10,x0,123

                    // Old handler: useful for diagnosing stale mtvec.
                    64'h80000100: instr_mem_data = 32'h05800593; // ADDI x11,x0,88
                    default: ;
                endcase
            end

            21: begin
                // Trap handler, MRET and resumed execution.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h04100113; // ADDI x2,x0,65
                    64'h0000000080000004: instr_mem_data = 32'h00800093; // ADDI x1,x0,8
                    64'h0000000080000008: instr_mem_data = 32'h30009073; // CSRRW x0,mstatus,x1
                    64'h000000008000000C: instr_mem_data = 32'h00013303; // LD x6,0(x2)
                    64'h0000000080000010: instr_mem_data = 32'h00700393; // ADDI x7,x0,7
                    64'h0000000080000014: instr_mem_data = 32'h00800413; // ADDI x8,x0,8
                    64'h0000000080000100: instr_mem_data = 32'h341022F3; // CSRRS x5,mepc,x0
                    64'h0000000080000104: instr_mem_data = 32'h00428293; // ADDI x5,x5,4
                    64'h0000000080000108: instr_mem_data = 32'h34129073; // CSRRW x0,mepc,x5
                    64'h000000008000010C: instr_mem_data = 32'h30200073; // MRET
                    64'h0000000080000110: instr_mem_data = 32'h06300593; // ADDI x11,x0,99 (must flush)
                    default: ;
                endcase
            end

            22: begin
                // Trap handler, MRET and resumed execution.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h04100113; // ADDI x2,x0,65
                    64'h0000000080000004: instr_mem_data = 32'h00800093; // ADDI x1,x0,8
                    64'h0000000080000008: instr_mem_data = 32'h30009073; // CSRRW x0,mstatus,x1
                    64'h000000008000000C: instr_mem_data = 32'h00013303; // LD x6,0(x2)
                    64'h0000000080000010: instr_mem_data = 32'h00700393; // ADDI x7,x0,7
                    64'h0000000080000014: instr_mem_data = 32'h00800413; // ADDI x8,x0,8
                    64'h0000000080000100: instr_mem_data = 32'h341022F3; // CSRRS x5,mepc,x0
                    64'h0000000080000104: instr_mem_data = 32'h00428293; // ADDI x5,x5,4
                    64'h0000000080000108: instr_mem_data = 32'h34129073; // CSRRW x0,mepc,x5
                    64'h000000008000010C: instr_mem_data = 32'h30200073; // MRET
                    64'h0000000080000110: instr_mem_data = 32'h00013583; // LD x11,0(x2), younger than MRET
                    default: ;
                endcase
            end

            23: begin
                // MRET cancels younger SD into valid RAM.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h04100113; // x2 = invalid address 65
                    64'h0000000080000004: instr_mem_data = 32'h00800093; // x1 = MIE
                    64'h0000000080000008: instr_mem_data = 32'h30009073; // Enable MIE
                    64'h000000008000000C: instr_mem_data = 32'h08000193; // x3 = RAM address 0x80
                    64'h0000000080000010: instr_mem_data = 32'h02A00213; // x4 = sentinel 42
                    64'h0000000080000014: instr_mem_data = 32'h00000013; // NOP
                    64'h0000000080000018: instr_mem_data = 32'h00000013; // NOP
                    64'h000000008000001C: instr_mem_data = 32'h0041B023; // SD x4,0(x3), initialize RAM
                    64'h0000000080000020: instr_mem_data = 32'h06300213; // x4 = forbidden value 99
                    64'h0000000080000024: instr_mem_data = 32'h00000013; // NOP
                    64'h0000000080000028: instr_mem_data = 32'h00000013; // NOP
                    64'h000000008000002C: instr_mem_data = 32'h00013303; // Faulting LD
                    64'h0000000080000030: instr_mem_data = 32'h0001B603; // LD x12,0(x3), check RAM
                    64'h0000000080000034: instr_mem_data = 32'h00700393; // Resume marker x7
                    64'h0000000080000038: instr_mem_data = 32'h00800413; // Resume marker x8
                    64'h0000000080000100: instr_mem_data = 32'h341022F3; // Read MEPC
                    64'h0000000080000104: instr_mem_data = 32'h00428293; // Skip faulting instruction
                    64'h0000000080000108: instr_mem_data = 32'h34129073; // Update MEPC
                    64'h000000008000010C: instr_mem_data = 32'h30200073; // MRET
                    64'h0000000080000110: instr_mem_data = 32'h0041B023; // Younger forbidden SD x4,0(x3)
                    default: ;
                endcase
            end

            24: begin
                // BEQ taken: squash x3, execute x4 and x5.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h00500093; // x1=5
                    64'h80000004: instr_mem_data = 32'h00500113; // x2=5
                    64'h80000008: instr_mem_data = 32'h00208463; // BEQ x1,x2,+8
                    64'h8000000C: instr_mem_data = 32'h06300193; // x3=99, squash
                    64'h80000010: instr_mem_data = 32'h00700213; // x4=7
                    64'h80000014: instr_mem_data = 32'h00800293; // x5=8
                    default: ;
                endcase
            end

            25: begin
                // BEQ not taken: x3, x4 and x5 must all execute.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h00500093; // x1=5
                    64'h80000004: instr_mem_data = 32'h00600113; // x2=6
                    64'h80000008: instr_mem_data = 32'h00208463; // BEQ x1,x2,+8
                    64'h8000000C: instr_mem_data = 32'h06300193; // x3=99
                    64'h80000010: instr_mem_data = 32'h00700213; // x4=7
                    64'h80000014: instr_mem_data = 32'h00800293; // x5=8
                    default: ;
                endcase
            end

            26: begin
                // CF-02: BNE taken, squash x3. Preserve x4/x5.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h00500093;
                    64'h0000000080000004: instr_mem_data = 32'h00600113;
                    64'h0000000080000008: instr_mem_data = 32'h00209463;
                    64'h000000008000000C: instr_mem_data = 32'h06300193;
                    64'h0000000080000010: instr_mem_data = 32'h00700213;
                    64'h0000000080000014: instr_mem_data = 32'h00800293;
                    default: ;
                endcase
            end

            27: begin
                // CF-02: BLT taken, squash x3. Preserve x4/x5.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'hFFF00093;
                    64'h0000000080000004: instr_mem_data = 32'h00100113;
                    64'h0000000080000008: instr_mem_data = 32'h0020C463;
                    64'h000000008000000C: instr_mem_data = 32'h06300193;
                    64'h0000000080000010: instr_mem_data = 32'h00700213;
                    64'h0000000080000014: instr_mem_data = 32'h00800293;
                    default: ;
                endcase
            end

            28: begin
                // CF-02: BGE taken, squash x3. Preserve x4/x5.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h00100093;
                    64'h0000000080000004: instr_mem_data = 32'hFFF00113;
                    64'h0000000080000008: instr_mem_data = 32'h0020D463;
                    64'h000000008000000C: instr_mem_data = 32'h06300193;
                    64'h0000000080000010: instr_mem_data = 32'h00700213;
                    64'h0000000080000014: instr_mem_data = 32'h00800293;
                    default: ;
                endcase
            end

            29: begin
                // CF-02: BLTU taken, squash x3. Preserve x4/x5.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h00100093;
                    64'h0000000080000004: instr_mem_data = 32'hFFF00113;
                    64'h0000000080000008: instr_mem_data = 32'h0020E463;
                    64'h000000008000000C: instr_mem_data = 32'h06300193;
                    64'h0000000080000010: instr_mem_data = 32'h00700213;
                    64'h0000000080000014: instr_mem_data = 32'h00800293;
                    default: ;
                endcase
            end

            30: begin
                // CF-02: BGEU taken, squash x3. Preserve x4/x5.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'hFFF00093;
                    64'h0000000080000004: instr_mem_data = 32'h00100113;
                    64'h0000000080000008: instr_mem_data = 32'h0020F463;
                    64'h000000008000000C: instr_mem_data = 32'h06300193;
                    64'h0000000080000010: instr_mem_data = 32'h00700213;
                    64'h0000000080000014: instr_mem_data = 32'h00800293;
                    default: ;
                endcase
            end

            31: begin
                // CF-02: backward BLT loop, x1 reaches 3.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h00000093;
                    64'h0000000080000004: instr_mem_data = 32'h00300113;
                    64'h0000000080000008: instr_mem_data = 32'h00108093;
                    64'h000000008000000C: instr_mem_data = 32'hFE20CEE3;
                    64'h0000000080000010: instr_mem_data = 32'h06300193;
                    64'h0000000080000014: instr_mem_data = 32'h00700213;
                    default: ;
                endcase
            end
            32: begin
                // CF-02: branch dependency integration test.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h00500093;
                    64'h0000000080000004: instr_mem_data = 32'h00600113;
                    64'h0000000080000008: instr_mem_data = 32'h00108093;
                    64'h000000008000000C: instr_mem_data = 32'h00208463;
                    64'h0000000080000010: instr_mem_data = 32'h06300193;
                    64'h0000000080000014: instr_mem_data = 32'h00700213;
                    default: ;
                endcase
            end

            33: begin
                // CF-02: branch dependency integration test.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h08000093;
                    64'h0000000080000004: instr_mem_data = 32'h00700113;
                    64'h0000000080000008: instr_mem_data = 32'h0020B023;
                    64'h000000008000000C: instr_mem_data = 32'h0000B283;
                    64'h0000000080000010: instr_mem_data = 32'h00228463;
                    64'h0000000080000014: instr_mem_data = 32'h06300193;
                    64'h0000000080000018: instr_mem_data = 32'h00700213;
                    default: ;
                endcase
            end
            34: begin
                // MEM trap beats EX BEQ.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h04100093;
                    64'h0000000080000004: instr_mem_data = 32'h00500113;
                    64'h0000000080000008: instr_mem_data = 32'h0000B303;
                    64'h000000008000000C: instr_mem_data = 32'h00000463;
                    64'h0000000080000010: instr_mem_data = 32'h06300393;
                    64'h0000000080000014: instr_mem_data = 32'h05800413;
                    64'h0000000080000100: instr_mem_data = 32'h07B00513;
                    default: ;
                endcase
            end

            35: begin
                // WB MRET beats EX BEQ.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h04100093;
                    64'h0000000080000004: instr_mem_data = 32'h0000B303;
                    64'h0000000080000008: instr_mem_data = 32'h00700393;
                    64'h000000008000000C: instr_mem_data = 32'h00800413;
                    64'h0000000080000100: instr_mem_data = 32'h341022F3;
                    64'h0000000080000104: instr_mem_data = 32'h00428293;
                    64'h0000000080000108: instr_mem_data = 32'h34129073;
                    64'h000000008000010C: instr_mem_data = 32'h30200073;
                    64'h0000000080000110: instr_mem_data = 32'h00000013;
                    64'h0000000080000114: instr_mem_data = 32'h00000463;
                    64'h0000000080000118: instr_mem_data = 32'h06300593;
                    64'h000000008000011C: instr_mem_data = 32'h05800613;
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
    .redirect        (trap_redirect),
    .redirect_target (trap_target),
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
