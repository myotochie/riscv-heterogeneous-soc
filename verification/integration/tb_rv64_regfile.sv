module tb_rv64_regfile;

    logic clk = 0;
    logic reset = 1;
    logic stall = 0;
    logic flush = 0;

    logic [63:0] pc_value;
    logic wb_we;
    logic [4:0] wb_rd;
    logic [63:0] wb_data;
    logic mem_wb_valid;
    logic [63:0] mem_wb_pc;
    logic [31:0] mem_wb_instr;

    rv64_pipeline dut (
        .clk(clk),
        .reset(reset),
        .stall(stall),
        .flush(flush),
        .pc_value(pc_value),
        .wb_we(wb_we),
        .wb_rd(wb_rd),
        .wb_data(wb_data),
        .mem_wb_valid(mem_wb_valid),
        .mem_wb_pc(mem_wb_pc),
        .mem_wb_instr(mem_wb_instr)
    );

    task automatic tick;
        begin
            #5 clk = 1;
            #5 clk = 0;
        end
    endtask

    initial begin
        tick();
        reset = 0;

        // 4 cycles to bring first instruction into MEM/WB,
        // then 3 more cycles to commit x1, x2 and x3.
        repeat (7) tick();

        if (dut.u_frontend.u_fetch_decode.u_decode.u_regfile.regs[1] !== 64'd5)
            $fatal(1, "FAIL: x1 expected 5");

        if (dut.u_frontend.u_fetch_decode.u_decode.u_regfile.regs[2] !== 64'd7)
            $fatal(1, "FAIL: x2 expected 7");

        if (dut.u_frontend.u_fetch_decode.u_decode.u_regfile.regs[3] !== 64'd9)
            $fatal(1, "FAIL: x3 expected 9");

        $display("[PASS] x1 = 5");
        $display("[PASS] x2 = 7");
        $display("[PASS] x3 = 9");
        $display("ALL REGISTER FILE TESTS PASSED");

        $finish;
    end

endmodule
