#include "Vwriteback_stage.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(bool condition, const char* name) {
    ++tests_run;

    if (condition) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name << '\n';
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vwriteback_stage dut{};

    // Configuration de base : instruction ALU valide.
    dut.alu_result_in = 42;
    dut.mem_data_in = 99;
    dut.rd_idx_in = 5;
    dut.reg_write_in = 1;
    dut.mem_to_reg_in = 0;
    dut.illegal_instr_in = 0;
    dut.valid_in = 1;
    dut.stall = 0;
    dut.eval();

    check(
        dut.wb_we == 1 && dut.wb_data == 42,
        "ALU result selected for write-back"
    );

    dut.mem_to_reg_in = 1;
    dut.eval();

    check(
        dut.wb_we == 1 && dut.wb_data == 99,
        "memory data selected for write-back"
    );

    dut.rd_idx_in = 12;
    dut.eval();

    check(
        dut.wb_rd == 12,
        "destination register propagated"
    );

    dut.valid_in = 0;
    dut.eval();

    check(
        dut.wb_we == 0,
        "invalid instruction cannot write"
    );

    dut.valid_in = 1;
    dut.illegal_instr_in = 1;
    dut.eval();

    check(
        dut.wb_we == 0,
        "illegal instruction cannot write"
    );

    dut.illegal_instr_in = 0;
    dut.reg_write_in = 0;
    dut.eval();

    check(
        dut.wb_we == 0,
        "reg_write disabled prevents writing"
    );

    dut.reg_write_in = 1;
    dut.rd_idx_in = 0;
    dut.eval();

    check(
        dut.wb_we == 0,
        "register x0 cannot be written"
    );

    dut.rd_idx_in = 5;
    dut.stall = 1;
    dut.eval();

    check(
        dut.wb_we == 0,
        "stall disables write-back"
    );

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
