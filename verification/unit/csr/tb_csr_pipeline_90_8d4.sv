`timescale 1ns/1ps

module tb_csr_pipeline_90_8d4;

    logic clk = 0;
    always #5 clk = ~clk;

    logic reset, flush, stall;
    logic valid_in, csr_valid_in, csr_write_enable_in;

    logic [63:0] pc_in, csr_new_value_in, csr_read_result_in;
    logic [31:0] instr_in;
    logic [11:0] csr_addr_in;

    logic [63:0] em_pc, em_new, em_read;
    logic [31:0] em_instr;
    logic [11:0] em_addr;
    logic em_valid, em_csr_valid, em_we;

    logic [63:0] wb_pc, wb_new, wb_read;
    logic [31:0] wb_instr;
    logic [11:0] wb_addr;
    logic wb_valid, wb_csr_valid, wb_we;

    integer tests = 0;
    integer failures = 0;

    pipeline_ex_mem u_ex_mem (
        .target_misaligned_in(1'b0),
        .control_target_in(64'b0),
        .target_misaligned_out(),
        .control_target_out(),
        .clk(clk), .reset(reset), .flush(flush), .stall(stall),
        .pc_in(pc_in),
        .instr_in(instr_in),
        .alu_result_in(64'b0),
        .rs2_value_in(64'b0),
        .rd_idx_in(5'b0),
        .reg_write_in(1'b0),
        .mem_read_in(1'b0),
        .mem_write_in(1'b0),
        .mem_to_reg_in(1'b0),
        .illegal_instr_in(1'b0),
        .valid_in(valid_in),
        .csr_valid_in(csr_valid_in),
        .csr_funct3_in(3'b001),
        .mret_valid_in(1'b0),
        .csr_addr_in(csr_addr_in),
        .csr_new_value_in(csr_new_value_in),
        .csr_read_result_in(csr_read_result_in),
        .csr_write_enable_in(csr_write_enable_in),
        .pc_out(em_pc),
        .instr_out(em_instr),
        .alu_result_out(),
        .rs2_value_out(),
        .rd_idx_out(),
        .reg_write_out(),
        .mem_read_out(),
        .mem_write_out(),
        .mem_to_reg_out(),
        .illegal_instr_out(),
        .valid_out(em_valid),
        .csr_valid_out(em_csr_valid),
        .csr_funct3_out(),
        .mret_valid_out(),
        .csr_addr_out(em_addr),
        .csr_new_value_out(em_new),
        .csr_read_result_out(em_read),
        .csr_write_enable_out(em_we)
    );

    pipeline_mem_wb u_mem_wb (
        .clk(clk), .reset(reset), .flush(flush), .stall(stall),
        .pc_in(em_pc),
        .instr_in(em_instr),
        .alu_result_in(64'b0),
        .mem_data_in(64'b0),
        .rd_idx_in(5'b0),
        .reg_write_in(1'b0),
        .mem_to_reg_in(1'b0),
        .illegal_instr_in(1'b0),
        .mem_fault_in(1'b0),
        .valid_in(em_valid),
        .csr_valid_in(em_csr_valid),
        .csr_funct3_in(3'b001),
        .mret_valid_in(1'b0),
        .csr_addr_in(em_addr),
        .csr_new_value_in(em_new),
        .csr_read_result_in(em_read),
        .csr_write_enable_in(em_we),
        .pc_out(wb_pc),
        .instr_out(wb_instr),
        .alu_result_out(),
        .mem_data_out(),
        .rd_idx_out(),
        .reg_write_out(),
        .mem_to_reg_out(),
        .illegal_instr_out(),
        .mem_fault_out(),
        .valid_out(wb_valid),
        .csr_valid_out(wb_csr_valid),
        .csr_funct3_out(),
        .mret_valid_out(),
        .csr_addr_out(wb_addr),
        .csr_new_value_out(wb_new),
        .csr_read_result_out(wb_read),
        .csr_write_enable_out(wb_we)
    );

    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    task automatic check(input bit condition, input string label);
        tests++;
        if (condition) begin
            $display("[PASS] %s", label);
        end else begin
            failures++;
            $display("[FAIL] %s", label);
        end
    endtask

    initial begin
        reset = 1;
        flush = 0;
        stall = 0;
        valid_in = 0;
        csr_valid_in = 0;
        csr_write_enable_in = 0;
        pc_in = 0;
        instr_in = 32'h00000013;
        csr_addr_in = 0;
        csr_new_value_in = 0;
        csr_read_result_in = 0;

        tick();
        check(em_we == 0 && wb_we == 0, "Reset clears CSR write enables");
        check(em_addr == 0 && wb_addr == 0, "Reset clears CSR addresses");

        @(negedge clk);
        reset = 0;
        valid_in = 1;
        csr_valid_in = 1;
        csr_write_enable_in = 1;
        pc_in = 64'h80000000;
        instr_in = 32'h30011073;
        csr_addr_in = 12'h300;
        csr_new_value_in = 64'h12345678;
        csr_read_result_in = 64'hABCDEF00;

        tick();
        check(em_we && em_addr == 12'h300, "EX/MEM CSR write metadata");
        check(em_new == 64'h12345678, "EX/MEM new CSR value");
        check(em_read == 64'hABCDEF00, "EX/MEM old CSR value");
        check(em_pc == 64'h80000000 && em_instr == 32'h30011073,
              "EX/MEM PC/instruction alignment");

        @(negedge clk);
        valid_in = 0;
        csr_valid_in = 0;
        csr_write_enable_in = 0;

        tick();
        check(wb_we && wb_addr == 12'h300, "MEM/WB CSR write metadata");
        check(wb_new == 64'h12345678 && wb_read == 64'hABCDEF00,
              "MEM/WB CSR values");
        check(wb_pc == 64'h80000000 && wb_instr == 32'h30011073,
              "MEM/WB PC/instruction alignment");

        @(negedge clk);
        stall = 1;
        pc_in = 64'h80000080;
        csr_addr_in = 12'h305;
        csr_new_value_in = 64'hDEADBEEF;

        tick();
        check(wb_addr == 12'h300 && wb_new == 64'h12345678,
              "Stall holds MEM/WB");
        check(em_addr == 12'h300, "Stall holds EX/MEM");

        @(negedge clk);
        stall = 0;
        flush = 1;

        tick();
        check(!em_we && !wb_we, "Flush clears CSR write enables");
        check(em_addr == 0 && wb_addr == 0, "Flush clears CSR addresses");

        @(negedge clk);
        flush = 0;
        valid_in = 1;
        csr_valid_in = 0;
        csr_write_enable_in = 1;

        tick();
        check(!em_we, "Non-CSR instruction cannot write CSR");

        @(negedge clk);
        valid_in = 0;
        csr_valid_in = 1;
        csr_write_enable_in = 1;

        tick();
        check(!em_we, "Invalid instruction cannot write CSR");

        $display("------------------------------------");
        $display("Tests run: %0d", tests);
        $display("Tests failed: %0d", failures);

        if (failures != 0)
            $fatal(1, "CSR pipeline tests failed");

        $display("[PASS] CSR pipeline transport");
        $finish;
    end

endmodule
