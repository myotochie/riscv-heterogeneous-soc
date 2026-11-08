#include "Vdecoder.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests = 0;
static int failures = 0;

static void check(bool condition, const char* description) {
    ++tests;
    if (condition) {
        std::cout << "[PASS] " << description << '\n';
    } else {
        ++failures;
        std::cerr << "[FAIL] " << description << '\n';
    }
}

static uint32_t branch_instruction(unsigned funct3) {
    // B-type, offset 0, rs1=x3, rs2=x4.
    return (4u << 20) |
           (3u << 15) |
           ((funct3 & 7u) << 12) |
           0x63u;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdecoder dut;

    const unsigned valid_funct3[] = {0, 1, 4, 5, 6, 7};
    const char* names[] = {
        "BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU"
    };

    for (unsigned i = 0; i < 6; ++i) {
        dut.instr = branch_instruction(valid_funct3[i]);
        dut.eval();

        check(
            !dut.illegal_instr &&
            dut.uses_rs1 &&
            dut.uses_rs2 &&
            !dut.reg_write &&
            !dut.mem_read &&
            !dut.mem_write &&
            !dut.csr_valid &&
            !dut.mret_valid,
            names[i]
        );
    }

    dut.instr = branch_instruction(2);
    dut.eval();
    check(
        dut.illegal_instr && !dut.uses_rs1 &&
        !dut.uses_rs2 && !dut.reg_write,
        "Reserved branch funct3=010"
    );

    dut.instr = branch_instruction(3);
    dut.eval();
    check(
        dut.illegal_instr && !dut.uses_rs1 &&
        !dut.uses_rs2 && !dut.reg_write,
        "Reserved branch funct3=011"
    );

    // Existing ADDI must remain supported.
    dut.instr = 0x00500093u;
    dut.eval();
    check(
        !dut.illegal_instr &&
        dut.reg_write && dut.uses_rs1 &&
        !dut.uses_rs2,
        "ADDI regression"
    );

    std::cout << "\nTests run: " << tests
              << "\nTests failed: " << failures << '\n';

    dut.final();
    return failures ? 1 : 0;
}
