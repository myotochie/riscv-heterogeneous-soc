module csr_file (
    input  logic        clk,
    input  logic        reset,

    // Trap capture interface.
    input  logic        trap_valid,
    input  logic [63:0] trap_epc,
    input  logic [63:0] trap_cause,
    input  logic [63:0] trap_tval,

    // CSR software access interface.
    input  logic        csr_we,
    input  logic [11:0] csr_raddr,
    input  logic [11:0] csr_waddr,
    input  logic [63:0] csr_wdata,
    output logic [63:0] csr_rdata,

    // Return from machine-mode trap.
    input  logic        mret_valid,

    // Architectural register observation.
    output logic [63:0] mtvec_o,
    output logic [63:0] mepc_o,
    output logic [63:0] mcause_o,
    output logic [63:0] mtval_o,
    output logic [63:0] mstatus_o
);

    localparam logic [11:0] CSR_MSTATUS = 12'h300;
    localparam logic [11:0] CSR_MTVEC   = 12'h305;
    localparam logic [11:0] CSR_MEPC    = 12'h341;
    localparam logic [11:0] CSR_MCAUSE  = 12'h342;
    localparam logic [11:0] CSR_MTVAL   = 12'h343;

    localparam logic [63:0] MTVEC_RESET =
        64'h0000_0000_8000_0100;

    // Implemented mstatus fields.
    localparam int MSTATUS_MIE  = 3;
    localparam int MSTATUS_MPIE = 7;
    localparam int MSTATUS_MPP_LSB = 11;

    logic [63:0] mstatus_q;
    logic [63:0] mtvec_q;
    logic [63:0] mepc_q;
    logic [63:0] mcause_q;
    logic [63:0] mtval_q;

    // Combinational CSR read.
    always_comb begin
        csr_rdata = 64'b0;

        case (csr_raddr)
            CSR_MSTATUS: csr_rdata = mstatus_q;
            CSR_MTVEC:   csr_rdata = mtvec_q;
            CSR_MEPC:    csr_rdata = mepc_q;
            CSR_MCAUSE:  csr_rdata = mcause_q;
            CSR_MTVAL:   csr_rdata = mtval_q;
            default:     csr_rdata = 64'b0;
        endcase
    end

    // Sequential architectural state.
    //
    // An older WB CSR instruction may retire on the same edge
    // as a younger MEM instruction raises an exception.
    //
    // Ordering inside this process:
    //   1. Older CSR retirement
    //   2. Trap updates to overlapping architectural fields
    //   3. MRET when no trap is present
    //
    // For overlapping nonblocking assignments, the later
    // assignment wins.

    always_ff @(posedge clk) begin
        if (reset) begin
            mstatus_q <= 64'h0000_0000_0000_1800;
            mtvec_q   <= MTVEC_RESET;
            mepc_q    <= 64'b0;
            mcause_q  <= 64'b0;
            mtval_q   <= 64'b0;

        end else begin

            // Older instruction retires in WB.
            if (csr_we) begin
                case (csr_waddr)
                    CSR_MSTATUS: begin
                        mstatus_q[MSTATUS_MIE] <=
                            csr_wdata[MSTATUS_MIE];

                        mstatus_q[MSTATUS_MPIE] <=
                            csr_wdata[MSTATUS_MPIE];
                    end

                    CSR_MTVEC: begin
                        // Direct mode only, aligned BASE.
                        mtvec_q <= {csr_wdata[63:2], 2'b00};
                    end

                    CSR_MEPC: begin
                        mepc_q <= {csr_wdata[63:2], 2'b00};
                    end

                    CSR_MCAUSE: begin
                        mcause_q <= csr_wdata;
                    end

                    CSR_MTVAL: begin
                        mtval_q <= csr_wdata;
                    end

                    default: begin
                        // Unimplemented CSR: no effect.
                    end
                endcase
            end

            // Younger fault: trap updates take precedence
            // over overlapping fields from the older CSR write.
            if (trap_valid) begin
                mepc_q   <= {trap_epc[63:2], 2'b00};
                mcause_q <= trap_cause;
                mtval_q  <= trap_tval;

                // MPIE receives the architecturally latest MIE.
                // When older WB writes mstatus on this edge,
                // its value must be considered.
                if (csr_we && csr_waddr == CSR_MSTATUS)
                    mstatus_q[MSTATUS_MPIE] <=
                        csr_wdata[MSTATUS_MIE];
                else
                    mstatus_q[MSTATUS_MPIE] <=
                        mstatus_q[MSTATUS_MIE];

                // Entering the trap disables interrupts.
                mstatus_q[MSTATUS_MIE] <= 1'b0;

                // Machine-only implementation.
                mstatus_q[MSTATUS_MPP_LSB +: 2] <= 2'b11;

            end else if (mret_valid) begin
                // MRET remains externally disconnected.
                mstatus_q[MSTATUS_MIE] <=
                    mstatus_q[MSTATUS_MPIE];

                mstatus_q[MSTATUS_MPIE] <= 1'b1;
                mstatus_q[MSTATUS_MPP_LSB +: 2] <= 2'b11;
            end
        end
    end

    assign mtvec_o   = mtvec_q;
    assign mepc_o    = mepc_q;
    assign mcause_o  = mcause_q;
    assign mtval_o   = mtval_q;
    assign mstatus_o = mstatus_q;

endmodule
