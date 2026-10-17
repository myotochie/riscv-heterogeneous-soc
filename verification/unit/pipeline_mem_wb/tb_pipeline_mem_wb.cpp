
#include "Vpipeline_mem_wb.h"
#include "verilated.h"

#include <cstdlib>
#include <iostream>

static int checks = 0;

static void check(bool condition, const char* message) {
    ++checks;
    if (!condition) {
        std::cerr << "[FAIL] " << message << '\n';
        std::exit(EXIT_FAILURE);
    }
}

static void tick(Vpipeline_mem_wb& dut) {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    dut.clk = 0;
    dut.eval();
}

static void clear_inputs(Vpipeline_mem_wb& dut) {
    dut.reset = 0;
    dut.flush = 0;
    dut.stall = 0;

    dut.pc_in = 0;
    dut.instr_in = 0x00000013;
    dut.alu_result_in = 0;
    dut.mem_data_in = 0;
    dut.rd_idx_in = 0;

    dut.reg_write_in = 0;
    dut.mem_to_reg_in = 0;
    dut.illegal_instr_in = 0;
    dut.valid_in = 0;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vpipeline_mem_wb dut;
    clear_inputs(dut);

    // 1. Reset
    dut.reset = 1;
    tick(dut);
    check(dut.pc_out == 0, "reset clears PC");
    check(dut.instr_out == 0x00000013, "reset inserts NOP");
    check(dut.alu_result_out == 0, "reset clears ALU result");
    check(dut.mem_data_out == 0, "reset clears memory data");
    check(dut.rd_idx_out == 0, "reset clears destination index");
    check(dut.reg_write_out == 0, "reset disables register write");
    check(dut.mem_to_reg_out == 0, "reset clears mem_to_reg");
    check(dut.illegal_instr_out == 0, "reset clears illegal flag");
    check(dut.valid_out == 0, "reset clears valid");

    // 2. Capture a valid instruction
    clear_inputs(dut);
    dut.pc_in = 0x80000100;
    dut.instr_in = 0x00A585B3;
    dut.alu_result_in = 0x123456789ABCDEF0ULL;
    dut.mem_data_in = 0xFEDCBA9876543210ULL;
    dut.rd_idx_in = 11;
    dut.reg_write_in = 1;
    dut.mem_to_reg_in = 1;
    dut.valid_in = 1;
    tick(dut);

    check(dut.pc_out == 0x80000100, "captures PC");
    check(dut.instr_out == 0x00A585B3, "captures instruction");
    check(dut.alu_result_out == 0x123456789ABCDEF0ULL,
          "captures ALU result");
    check(dut.mem_data_out == 0xFEDCBA9876543210ULL,
          "captures memory data");
    check(dut.rd_idx_out == 11, "captures destination index");
    check(dut.reg_write_out == 1, "captures register write control");
    check(dut.mem_to_reg_out == 1, "captures mem_to_reg control");
    check(dut.valid_out == 1, "captures valid");

    // 3. Stall holds all outputs
    dut.pc_in = 0x80000200;
    dut.instr_in = 0xFFFFFFFF;
    dut.alu_result_in = 0xAAAAAAAAAAAAAAAAULL;
    dut.mem_data_in = 0xBBBBBBBBBBBBBBBBULL;
    dut.rd_idx_in = 7;
    dut.reg_write_in = 0;
    dut.mem_to_reg_in = 0;
    dut.valid_in = 0;
    dut.stall = 1;
    tick(dut);

    check(dut.pc_out == 0x80000100, "stall holds PC");
    check(dut.instr_out == 0x00A585B3, "stall holds instruction");
    check(dut.alu_result_out == 0x123456789ABCDEF0ULL,
          "stall holds ALU result");
    check(dut.mem_data_out == 0xFEDCBA9876543210ULL,
          "stall holds memory data");
    check(dut.rd_idx_out == 11, "stall holds destination index");
    check(dut.reg_write_out == 1, "stall holds register write");
    check(dut.mem_to_reg_out == 1, "stall holds mem_to_reg");
    check(dut.valid_out == 1, "stall holds valid");

    // 4. Flush has priority over stall
    dut.flush = 1;
    tick(dut);

    check(dut.pc_out == 0, "flush clears PC despite stall");
    check(dut.instr_out == 0x00000013, "flush inserts NOP");
    check(dut.alu_result_out == 0, "flush clears ALU result");
    check(dut.mem_data_out == 0, "flush clears memory data");
    check(dut.rd_idx_out == 0, "flush clears destination index");
    check(dut.reg_write_out == 0, "flush disables register write");
    check(dut.mem_to_reg_out == 0, "flush clears mem_to_reg");
    check(dut.valid_out == 0, "flush clears valid");

    // 5. Invalid input must disable side-effect controls
    clear_inputs(dut);
    dut.pc_in = 0x80000300;
    dut.instr_in = 0xFFFFFFFF;
    dut.rd_idx_in = 9;
    dut.reg_write_in = 1;
    dut.mem_to_reg_in = 1;
    dut.illegal_instr_in = 1;
    dut.valid_in = 0;
    tick(dut);

    check(dut.pc_out == 0x80000300, "captures data fields when invalid");
    check(dut.rd_idx_out == 9, "captures destination when invalid");
    check(dut.reg_write_out == 0, "invalid input disables register write");
    check(dut.mem_to_reg_out == 0, "invalid input disables mem_to_reg");
    check(dut.illegal_instr_out == 0, "invalid input clears illegal flag");
    check(dut.valid_out == 0, "invalid input remains invalid");

    std::cout << "[PASS] pipeline_mem_wb: "
              << checks << " checks passed\n";
    return EXIT_SUCCESS;
}
