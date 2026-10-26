
#include "Vimm_gen.h"
#include "verilated.h"

#include <cstdint>
#include <iomanip>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

uint32_t encode_i_type(int16_t immediate) {
    const uint32_t imm12 =
        static_cast<uint16_t>(immediate) & 0x0FFF;

    return imm12 << 20;
}

uint32_t encode_s_type(int16_t immediate) {
    const uint32_t imm12 =
        static_cast<uint16_t>(immediate) & 0x0FFF;

    return ((imm12 >> 5) << 25)
         | (5U << 20)       // rs2 = x5
         | (1U << 15)       // rs1 = x1
         | (3U << 12)       // funct3 = SD
         | ((imm12 & 0x1F) << 7)
         | 0x23U;          // STORE opcode
}

void check_immediate(
    Vimm_gen& dut,
    int16_t immediate,
    uint64_t expected,
    const char* name
) {
    dut.instr = encode_i_type(immediate);
    dut.eval();

    ++tests_run;

    const uint64_t actual = dut.imm;

    if (actual == expected) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;

        std::cout << "[FAIL] " << name
                  << " | expected=0x"
                  << std::hex << expected
                  << " actual=0x" << actual
                  << std::dec << '\n';
    }
}

void check_s_immediate(
    Vimm_gen& dut,
    int16_t immediate,
    uint64_t expected,
    const char* name
) {
    dut.instr = encode_s_type(immediate);
    dut.eval();

    ++tests_run;

    const uint64_t actual = dut.imm;

    if (actual == expected) {
        std::cout << "[PASS] " << name << '\\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | expected=0x"
                  << std::hex << expected
                  << " actual=0x" << actual
                  << std::dec << '\\n';
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vimm_gen dut{};

    check_immediate(
        dut, 42, 0x000000000000002AULL, "ADDI immediate +42");

    check_immediate(
        dut, -1, 0xFFFFFFFFFFFFFFFFULL, "ADDI immediate -1");

    check_immediate(
        dut, -2048, 0xFFFFFFFFFFFFF800ULL, "ADDI immediate -2048");

    check_immediate(
        dut, 2047, 0x00000000000007FFULL, "ADDI immediate +2047");

    // RV64I S-type immediate tests.
    check_s_immediate(
        dut, 16, 0x0000000000000010ULL,
        "SD immediate +16");

    check_s_immediate(
        dut, -8, 0xFFFFFFFFFFFFFFF8ULL,
        "SD immediate -8");

    check_s_immediate(
        dut, 2047, 0x00000000000007FFULL,
        "SD immediate +2047");

    check_s_immediate(
        dut, -2048, 0xFFFFFFFFFFFFF800ULL,
        "SD immediate -2048");

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
