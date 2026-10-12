
#include "Vdecoder.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

// Values must match alu_op_t in core_pkg.sv.
enum AluOp : uint8_t {
    ALU_ADD  = 0,
    ALU_SUB  = 1,
    ALU_AND  = 2,
    ALU_OR   = 3,
    ALU_XOR  = 4,
    ALU_SLL  = 5,
    ALU_SRL  = 6,
    ALU_SRA  = 7,
    ALU_SLT  = 8,
    ALU_SLTU = 9
};

uint32_t encode_r_type(
    uint8_t funct7,
    uint8_t rs2,
    uint8_t rs1,
    uint8_t funct3,
    uint8_t rd,
    uint8_t opcode = 0x33
) {
    return (static_cast<uint32_t>(funct7) << 25)
         | (static_cast<uint32_t>(rs2) << 20)
         | (static_cast<uint32_t>(rs1) << 15)
         | (static_cast<uint32_t>(funct3) << 12)
         | (static_cast<uint32_t>(rd) << 7)
         | opcode;
}

void check_instruction(
    Vdecoder& dut,
    uint32_t instruction,
    uint8_t expected_rd,
    uint8_t expected_rs1,
    uint8_t expected_rs2,
    AluOp expected_alu_op,
    bool expected_reg_write,
    bool expected_illegal,
    const char* name
) {
    dut.instr = instruction;
    dut.eval();

    ++tests_run;

    const bool pass =
        dut.rd == expected_rd &&
        dut.rs1 == expected_rs1 &&
        dut.rs2 == expected_rs2 &&
        dut.alu_op == expected_alu_op &&
        dut.reg_write == expected_reg_write &&
        dut.illegal_instr == expected_illegal;

    if (pass) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | rd=" << static_cast<int>(dut.rd)
                  << " rs1=" << static_cast<int>(dut.rs1)
                  << " rs2=" << static_cast<int>(dut.rs2)
                  << " alu_op=" << static_cast<int>(dut.alu_op)
                  << " reg_write=" << static_cast<int>(dut.reg_write)
                  << " illegal=" << static_cast<int>(dut.illegal_instr)
                  << '\n';
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdecoder dut{};

    constexpr uint8_t rd = 7;
    constexpr uint8_t rs1 = 12;
    constexpr uint8_t rs2 = 19;

    // Ten supported RV64I R-type instructions.
    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b000, rd),
        rd, rs1, rs2, ALU_ADD, true, false, "ADD");

    check_instruction(dut, encode_r_type(0x20, rs2, rs1, 0b000, rd),
        rd, rs1, rs2, ALU_SUB, true, false, "SUB");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b001, rd),
        rd, rs1, rs2, ALU_SLL, true, false, "SLL");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b010, rd),
        rd, rs1, rs2, ALU_SLT, true, false, "SLT");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b011, rd),
        rd, rs1, rs2, ALU_SLTU, true, false, "SLTU");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b100, rd),
        rd, rs1, rs2, ALU_XOR, true, false, "XOR");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b101, rd),
        rd, rs1, rs2, ALU_SRL, true, false, "SRL");

    check_instruction(dut, encode_r_type(0x20, rs2, rs1, 0b101, rd),
        rd, rs1, rs2, ALU_SRA, true, false, "SRA");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b110, rd),
        rd, rs1, rs2, ALU_OR, true, false, "OR");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b111, rd),
        rd, rs1, rs2, ALU_AND, true, false, "AND");

    // Unsupported opcode.
    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b000, rd, 0x13),
        rd, rs1, rs2, ALU_ADD, false, true, "unsupported opcode");

    // Invalid funct7 for ADD.
    check_instruction(dut, encode_r_type(0x01, rs2, rs1, 0b000, rd),
        rd, rs1, rs2, ALU_ADD, false, true, "invalid ADD funct7");

    // Invalid funct7 for AND.
    check_instruction(dut, encode_r_type(0x20, rs2, rs1, 0b111, rd),
        rd, rs1, rs2, ALU_ADD, false, true, "invalid AND funct7");

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
