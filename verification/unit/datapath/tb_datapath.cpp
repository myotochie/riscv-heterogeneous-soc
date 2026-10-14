
#include "Vrv64_datapath.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

uint32_t encode_i_type(
    int16_t imm, uint8_t rs1, uint8_t funct3, uint8_t rd
) {
    return ((static_cast<uint32_t>(imm) & 0xFFF) << 20)
         | (static_cast<uint32_t>(rs1) << 15)
         | (static_cast<uint32_t>(funct3) << 12)
         | (static_cast<uint32_t>(rd) << 7)
         | 0x13;
}

uint32_t encode_r_type(
    uint8_t funct7, uint8_t rs2, uint8_t rs1,
    uint8_t funct3, uint8_t rd
) {
    return (static_cast<uint32_t>(funct7) << 25)
         | (static_cast<uint32_t>(rs2) << 20)
         | (static_cast<uint32_t>(rs1) << 15)
         | (static_cast<uint32_t>(funct3) << 12)
         | (static_cast<uint32_t>(rd) << 7)
         | 0x33;
}

void check_result(
    Vrv64_datapath& dut,
    uint32_t instruction,
    uint64_t expected,
    bool expected_illegal,
    const char* name
) {
    dut.clk = 0;
    dut.instr = instruction;
    dut.eval();

    ++tests_run;

    const uint64_t actual = dut.result;
    const bool illegal = dut.illegal_instr;

    if (actual == expected && illegal == expected_illegal) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | expected result=" << expected
                  << ", actual=" << actual
                  << ", expected illegal=" << expected_illegal
                  << ", actual illegal=" << illegal << '\n';
    }

    // Commit any valid register write on the rising clock edge.
    dut.clk = 1;
    dut.eval();
    dut.clk = 0;
    dut.eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_datapath dut{};

    // ADDI x1, x0, 42
    check_result(
        dut, encode_i_type(42, 0, 0, 1),
        42, false, "ADDI initializes x1 to 42");

    // ADDI x2, x0, 99
    check_result(
        dut, encode_i_type(99, 0, 0, 2),
        99, false, "ADDI initializes x2 to 99");

    // ADD x3, x1, x2: 42 + 99 = 141
    check_result(
        dut, encode_r_type(0x00, 2, 1, 0x0, 3),
        141, false, "ADD x1 and x2");

    // SUB x4, x2, x1: 99 - 42 = 57
    check_result(
        dut, encode_r_type(0x20, 1, 2, 0x0, 4),
        57, false, "SUB x2 and x1");

    // ADDI x5, x1, 0: read back x1 and verify its value.
    check_result(
        dut, encode_i_type(0, 1, 0, 5),
        42, false, "Read back x1");

    // An unsupported opcode must be rejected.
    const uint32_t illegal_instruction = 0x0000007F;
    check_result(
        dut, illegal_instruction,
        0, true, "Reject illegal instruction");

    // The x0 register must always read as zero.
    check_result(
        dut, encode_i_type(0, 0, 0, 6),
        0, false, "x0 remains zero");

    std::cout << "\nTests run: " << tests_run
              << "\nTests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
