module fetch_path #(
    parameter bit RAW_TEST_PROGRAM = 1'b0,
    parameter int unsigned PROGRAM_ID = 0,
    parameter string IMEM_FILE = "",
    parameter int unsigned IMEM_WORDS = 1024,
    parameter logic [63:0] IMEM_BASE = 64'h0000000080000000
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
    logic [31:0] selected_instr_data;

    generate if (IMEM_FILE != "") begin : g_external_imem
        logic address_fault;
        instruction_memory #(
            .INIT_FILE(IMEM_FILE), .WORDS(IMEM_WORDS), .BASE_ADDR(IMEM_BASE)
        ) u_imem (
            .address(pc_value), .instruction(selected_instr_data), .address_fault(address_fault)
        );
        // Simulation diagnostic on an accepted fetch, not an architectural trap.
        // Redirects flush IF/ID, so discarded old-path addresses are ignored.
`ifndef SYNTHESIS
        always_ff @(posedge clk) begin
            if (!reset && !flush && !stall_if_id && address_fault)
                $fatal(1, "IMEM_FETCH_ADDRESS: invalid accepted PC %h", pc_value);
        end
`endif
    end else begin : g_legacy_imem
        assign selected_instr_data = instr_mem_data;
    end endgenerate

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

            36: begin
                // CF-03: Nested calls, saved RA, alternate link, negative JALR, rd=rs1 and odd target.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h08000A13; // ADDI x20,x0,128
                    64'h0000000080000004: instr_mem_data = 32'h03C000EF; // JAL x1,function
                    64'h0000000080000008: instr_mem_data = 32'h00008513; // Copy restored RA
                    64'h000000008000000C: instr_mem_data = 32'h0740006F; // JAL x0,next
                    64'h0000000080000010: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h0000000080000014: instr_mem_data = 32'h000A3023; // Wrong-path store
                    64'h0000000080000040: instr_mem_data = 32'h00008593; // Consume link at target
                    64'h0000000080000044: instr_mem_data = 32'h001A3023; // Save RA
                    64'h0000000080000048: instr_mem_data = 32'h018002EF; // Nested call with x5
                    64'h000000008000004C: instr_mem_data = 32'h000A3083; // Restore RA
                    64'h0000000080000050: instr_mem_data = 32'h00008067; // RET with load-use
                    64'h0000000080000054: instr_mem_data = 32'h000A3023; // Wrong-path store
                    64'h0000000080000060: instr_mem_data = 32'h00028613; // Consume nested link
                    64'h0000000080000064: instr_mem_data = 32'h00028067; // Return backwards
                    64'h0000000080000068: instr_mem_data = 32'h30501073; // Wrong-path MTVEC write
                    64'h0000000080000074: instr_mem_data = 32'h04C0006F; // Forward to done
                    64'h0000000080000080: instr_mem_data = 32'h0100036F; // JAL x6,+16
                    64'h0000000080000084: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h0000000080000090: instr_mem_data = 32'h02D30313; // Build odd target 0x800000b1
                    64'h0000000080000094: instr_mem_data = 32'h00030367; // JALR rd=rs1, clear bit zero
                    64'h0000000080000098: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h00000000800000A0: instr_mem_data = 32'h00038793; // Link must be 0x800000bc
                    64'h00000000800000A4: instr_mem_data = 32'hFD1FF06F; // Backward JAL to 0x74
                    64'h00000000800000B0: instr_mem_data = 32'h00030693; // Link must be 0x80000098
                    64'h00000000800000B4: instr_mem_data = 32'h02030713; // Base for negative offset
                    64'h00000000800000B8: instr_mem_data = 32'hFE8703E7; // Negative JALR offset to 0xa0
                    64'h00000000800000C0: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            37: begin
                // CF-03: ALU, CSR and load forwarding into JALR.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h020000EF; // Get PC
                    64'h0000000080000020: instr_mem_data = 32'h03C08113; // ALU target 0x40
                    64'h0000000080000024: instr_mem_data = 32'h000101E7; // EX/MEM ALU -> JALR
                    64'h0000000080000028: instr_mem_data = 32'h00030393; // Copy link
                    64'h000000008000002C: instr_mem_data = 32'h08000A13; // Memory base
                    64'h0000000080000030: instr_mem_data = 32'h07C08413; // Load target 0x80
                    64'h0000000080000034: instr_mem_data = 32'h008A3023; // Store target
                    64'h0000000080000038: instr_mem_data = 32'h000A3483; // Load target
                    64'h000000008000003C: instr_mem_data = 32'h00048567; // Load-use JALR
                    64'h0000000080000040: instr_mem_data = 32'h34119273; // MEPC = 0x28 (implemented CSR)
                    64'h0000000080000044: instr_mem_data = 32'h341022F3; // Read MEPC target
                    64'h0000000080000048: instr_mem_data = 32'h00028367; // EX/MEM CSR -> JALR to 0x28
                    64'h0000000080000080: instr_mem_data = 32'h00050593; // Copy link
                    64'h0000000080000084: instr_mem_data = 32'h00C0006F; // Skip
                    64'h0000000080000090: instr_mem_data = 32'h06000613; // Marker
                    64'h0000000080000094: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            38: begin
                // CF-03: Precise misaligned jump exception.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h00700113; // Older instruction must retire
                    64'h0000000080000004: instr_mem_data = 32'h002000EF; // Misaligned JAL, no link
                    64'h0000000080000008: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h000000008000000C: instr_mem_data = 32'h00203023; // Wrong-path nonzero store
                    64'h0000000080000010: instr_mem_data = 32'h30511073; // Wrong-path MTVEC write
                    64'h0000000080000100: instr_mem_data = 32'h07B00513; // Trap handler
                    64'h0000000080000104: instr_mem_data = 32'h00003583; // No younger store
                    64'h0000000080000108: instr_mem_data = 32'h30502673; // MTVEC must remain unchanged
                    64'h000000008000010C: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            39: begin
                // CF-03: Precise misaligned jump exception.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h00700113; // Older instruction must retire
                    64'h0000000080000004: instr_mem_data = 32'h01C000EF; // Get link 8
                    64'h0000000080000020: instr_mem_data = 32'h01B08113; // Odd target 0x23
                    64'h0000000080000024: instr_mem_data = 32'h000100E7; // Fault target 0x22 after bit-zero mask
                    64'h0000000080000028: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h000000008000002C: instr_mem_data = 32'h00203023; // Wrong-path nonzero store
                    64'h0000000080000030: instr_mem_data = 32'h30511073; // Wrong-path MTVEC write
                    64'h0000000080000100: instr_mem_data = 32'h07B00513; // Trap handler
                    64'h0000000080000104: instr_mem_data = 32'h00003583; // No younger store
                    64'h0000000080000108: instr_mem_data = 32'h30502673; // MTVEC must remain unchanged
                    64'h000000008000010C: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            40: begin
                // CF-03: Older MEM load fault beats EX JAL.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h04100093; // Misaligned address
                    64'h0000000080000004: instr_mem_data = 32'h0000B303; // Fault
                    64'h0000000080000008: instr_mem_data = 32'h018002EF; // Younger jump
                    64'h000000008000000C: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h0000000080000020: instr_mem_data = 32'h05800F93; // Canceled target
                    64'h0000000080000100: instr_mem_data = 32'h07B00513; // Handler
                    64'h0000000080000104: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            41: begin
                // CF-03: WB MRET beats MEM jump fault and EX jump.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h04100093; // Misaligned address
                    64'h0000000080000004: instr_mem_data = 32'h0000B303; // Fault
                    64'h0000000080000008: instr_mem_data = 32'h00700393; // Resume
                    64'h000000008000000C: instr_mem_data = 32'h00800413; // Resume
                    64'h0000000080000010: instr_mem_data = 32'h0000006F; // Done loop
                    64'h0000000080000100: instr_mem_data = 32'h341022F3; // Read MEPC
                    64'h0000000080000104: instr_mem_data = 32'h00428293; // Skip LD
                    64'h0000000080000108: instr_mem_data = 32'h34129073; // Write MEPC
                    64'h000000008000010C: instr_mem_data = 32'h30200073; // MRET
                    64'h0000000080000110: instr_mem_data = 32'h002005EF; // Canceled MEM jump fault
                    64'h0000000080000114: instr_mem_data = 32'h13828667; // Canceled EX JALR to 0x140
                    64'h0000000080000140: instr_mem_data = 32'h06300F13; // Canceled target
                    default: ;
                endcase
            end

            42: begin
                // CF-03: Older WB MTVEC write determines jump trap target.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h020000EF; // Get PC
                    64'h0000000080000020: instr_mem_data = 32'h17C08113; // New MTVEC 0x180
                    64'h0000000080000024: instr_mem_data = 32'h30511073; // Commit MTVEC at jump trap
                    64'h0000000080000028: instr_mem_data = 32'h002002EF; // Misaligned jump
                    64'h000000008000002C: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h0000000080000100: instr_mem_data = 32'h06300F93; // Old handler forbidden
                    64'h0000000080000180: instr_mem_data = 32'h07B00513; // New handler
                    64'h0000000080000184: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            43: begin
                // CF-03: Reserved JALR encodings do not redirect or write.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h02000093; // Base
                    64'h0000000080000004: instr_mem_data = 32'h000092E7; // Reserved funct3=1
                    64'h0000000080000008: instr_mem_data = 32'h0000A2E7; // Reserved funct3=2
                    64'h000000008000000C: instr_mem_data = 32'h0000B2E7; // Reserved funct3=3
                    64'h0000000080000010: instr_mem_data = 32'h0000C2E7; // Reserved funct3=4
                    64'h0000000080000014: instr_mem_data = 32'h0000D2E7; // Reserved funct3=5
                    64'h0000000080000018: instr_mem_data = 32'h0000E2E7; // Reserved funct3=6
                    64'h000000008000001C: instr_mem_data = 32'h0000F2E7; // Reserved funct3=7
                    64'h0000000080000020: instr_mem_data = 32'h07B00513; // Fallthrough
                    64'h0000000080000024: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            44: begin
                // CF-03: JALR forwarding priority and MEM/WB path.
                case (pc_value)
                    64'h0000000080000000: instr_mem_data = 32'h020000EF; // Get PC
                    64'h0000000080000020: instr_mem_data = 32'h03C08113; // Older target 0x40
                    64'h0000000080000024: instr_mem_data = 32'h05C08113; // Newer target 0x60
                    64'h0000000080000028: instr_mem_data = 32'h000101E7; // Newest target wins
                    64'h0000000080000040: instr_mem_data = 32'h06300F13; // Stale target forbidden
                    64'h0000000080000060: instr_mem_data = 32'h07C08213; // Target 0x80
                    64'h0000000080000064: instr_mem_data = 32'h00000013; // Gap
                    64'h0000000080000068: instr_mem_data = 32'h000202E7; // MEM/WB -> JALR
                    64'h0000000080000080: instr_mem_data = 32'h00028513; // Link 0x6c
                    64'h0000000080000084: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            45: begin
                // CF-03: JAL immediate aliases load rd=x5, without a dependency.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h00003283; // LD x5,0(x0)
                    64'h80000004: instr_mem_data = 32'h000280EF; // JAL x1,+0x28000
                    64'h80000008: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h80028004: instr_mem_data = 32'h00008513; // Copy link
                    64'h80028008: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            46: begin
                // CF-03: a misaligned branch target faults only when taken.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h00100093; // ADDI x1,x0,1
                    64'h80000004: instr_mem_data = 32'h00109163; // BNE x1,x1,+2 (not taken)
                    64'h80000008: instr_mem_data = 32'h00108163; // BEQ x1,x1,+2 (taken)
                    64'h8000000C: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h80000100: instr_mem_data = 32'h07B00513; // Handler marker
                    64'h80000104: instr_mem_data = 32'h0000006F; // Done loop
                    default: ;
                endcase
            end

            47: begin
                // CF-03 audit: an older MEM fault beats EX JALR.
                case (pc_value)
                    64'h80000000: instr_mem_data = 32'h04100093; // x1=65
                    64'h80000004: instr_mem_data = 32'h0000B303; // Misaligned LD
                    64'h80000008: instr_mem_data = 32'hFDF082E7; // JALR x5,x1,-33 -> 0x20
                    64'h8000000C: instr_mem_data = 32'h06300F13; // Wrong path
                    64'h00000020: instr_mem_data = 32'h05800F93; // Forbidden JALR target
                    64'h80000100: instr_mem_data = 32'h07B00513; // Handler
                    64'h80000104: instr_mem_data = 32'h0000006F; // Done
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
        .instr_in  (selected_instr_data),
        .valid_in  (1'b1),

        .pc_out    (if_id_pc),
        .instr_out (if_id_instr),
        .valid_out (if_id_valid)
    );

endmodule
