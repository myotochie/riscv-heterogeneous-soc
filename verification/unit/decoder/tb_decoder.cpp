
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



uint32_t encode_i_type(
    int16_t imm,
    uint8_t rs1,
    uint8_t funct3,
    uint8_t rd,
    uint8_t opcode = 0x13
) {
    return (static_cast<uint32_t>(static_cast<uint16_t>(imm) & 0x0FFF) << 20)
         | (static_cast<uint32_t>(rs1) << 15)
         | (static_cast<uint32_t>(funct3) << 12)
         | (static_cast<uint32_t>(rd) << 7)
         | opcode;
}

uint32_t encode_s_type(
    int16_t imm,
    uint8_t rs2,
    uint8_t rs1,
    uint8_t funct3,
    uint8_t opcode = 0x23
) {
    const uint32_t imm12 =
        static_cast<uint16_t>(imm) & 0x0FFF;

    return ((imm12 >> 5) << 25)
         | (static_cast<uint32_t>(rs2) << 20)
         | (static_cast<uint32_t>(rs1) << 15)
         | (static_cast<uint32_t>(funct3) << 12)
         | ((imm12 & 0x1F) << 7)
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
    bool expected_alu_src,
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
        dut.alu_src == expected_alu_src &&
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
                  << " alu_src=" << static_cast<int>(dut.alu_src)
                  << " illegal=" << static_cast<int>(dut.illegal_instr)
                  << '\n';
    }
}


void check_control_signals(
    Vdecoder& dut,
    uint32_t instruction,
    bool expected_mem_read,
    bool expected_uses_rs1,
    bool expected_uses_rs2,
    const char* name
) {
    dut.instr = instruction;
    dut.eval();

    ++tests_run;

    const bool pass =
        dut.mem_read == expected_mem_read &&
        dut.uses_rs1 == expected_uses_rs1 &&
        dut.uses_rs2 == expected_uses_rs2;

    if (pass) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | mem_read=" << static_cast<int>(dut.mem_read)
                  << " uses_rs1=" << static_cast<int>(dut.uses_rs1)
                  << " uses_rs2=" << static_cast<int>(dut.uses_rs2)
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
        rd, rs1, rs2, ALU_ADD, true, false,false, "ADD");

    check_instruction(dut, encode_r_type(0x20, rs2, rs1, 0b000, rd),
        rd, rs1, rs2, ALU_SUB, true, false,false, "SUB");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b001, rd),
        rd, rs1, rs2, ALU_SLL, true, false,false, "SLL");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b010, rd),
        rd, rs1, rs2, ALU_SLT, true, false,false, "SLT");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b011, rd),
        rd, rs1, rs2, ALU_SLTU, true, false,false, "SLTU");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b100, rd),
        rd, rs1, rs2, ALU_XOR, true, false,false, "XOR");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b101, rd),
        rd, rs1, rs2, ALU_SRL, true, false,false, "SRL");

    check_instruction(dut, encode_r_type(0x20, rs2, rs1, 0b101, rd),
        rd, rs1, rs2, ALU_SRA, true, false,false, "SRA");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b110, rd),
        rd, rs1, rs2, ALU_OR, true, false,false, "OR");

    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b111, rd),
        rd, rs1, rs2, ALU_AND, true, false,false, "AND");

    // Unsupported opcode.
    check_instruction(dut, encode_r_type(0x00, rs2, rs1, 0b000, rd, 0x7F),
        rd, rs1, rs2, ALU_ADD, false, true,false, "unsupported opcode");

    // Invalid funct7 for ADD.
    check_instruction(dut, encode_r_type(0x01, rs2, rs1, 0b000, rd),
        rd, rs1, rs2, ALU_ADD, false, true,false, "invalid ADD funct7");

    // Invalid funct7 for AND.
    check_instruction(dut, encode_r_type(0x20, rs2, rs1, 0b111, rd),
        rd, rs1, rs2, ALU_ADD, false, true,false, "invalid AND funct7");


    // Valid ADDI instructions.
    check_instruction(dut, encode_i_type(42, rs1, 0b000, rd),
        rd, rs1, 10, ALU_ADD, true, false, true, "ADDI +42");

    check_instruction(dut, encode_i_type(-1, rs1, 0b000, rd),
        rd, rs1, 31, ALU_ADD, true, false, true, "ADDI -1");

    check_instruction(dut, encode_i_type(-2048, rs1, 0b000, rd),
        rd, rs1, 0, ALU_ADD, true, false, true, "ADDI -2048");

    check_instruction(dut, encode_i_type(2047, rs1, 0b000, rd),
        rd, rs1, 31, ALU_ADD, true, false, true, "ADDI +2047");

    // Unsupported immediate funct3.
    check_instruction(dut, encode_i_type(42, rs1, 0b001, rd),
        rd, rs1, 10, ALU_ADD, false, true, false,
        "unsupported immediate funct3");



    // RV64I LD: 64-bit load.
    check_instruction(dut, encode_i_type(16, rs1, 0b011, rd, 0x03),
        rd, rs1, 16, ALU_ADD, true, false, true, "LD +16");

    check_control_signals(dut, encode_i_type(16, rs1, 0b011, rd, 0x03),
        true, true, false, "LD control signals");

    check_instruction(dut, encode_i_type(-8, rs1, 0b011, rd, 0x03),
        rd, rs1, 24, ALU_ADD, true, false, true, "LD -8");

    check_control_signals(dut, encode_i_type(-8, rs1, 0b011, rd, 0x03),
        true, true, false, "LD negative offset controls");

    // LW is not implemented yet.
    check_instruction(dut, encode_i_type(16, rs1, 0b010, rd, 0x03),
        rd, rs1, 16, ALU_ADD, false, true, false,
        "unsupported LW");

    check_control_signals(dut, encode_i_type(16, rs1, 0b010, rd, 0x03),
        false, false, false, "unsupported LW controls");

    // Arithmetic instructions must not request a memory read.
    check_control_signals(dut, encode_i_type(42, rs1, 0b000, rd),
        false, true, false, "ADDI controls");

    check_control_signals(dut,
        encode_r_type(0x00, rs2, rs1, 0b000, rd),
        false, true, true, "ADD controls");

    // Illegal instruction must not consume register operands.
    check_control_signals(dut,
        encode_r_type(0x01, rs2, rs1, 0b000, rd),
        false, false, false, "illegal instruction controls");

    // RV64I SD: store doubleword, positive offset.
    dut.instr = encode_s_type(16, 5, 1, 0b011);
    dut.eval();

    check_control_signals(
        dut, encode_s_type(16, 5, 1, 0b011),
        false, true, true,
        "SD positive offset controls"
    );

    // Verify all store-specific controls.
    ++tests_run;
    if (dut.rs1 == 1 &&
        dut.rs2 == 5 &&
        dut.alu_op == ALU_ADD &&
        dut.alu_src == 1 &&
        dut.reg_write == 0 &&
        dut.mem_write == 1 &&
        dut.illegal_instr == 0) {
        std::cout << "[PASS] SD decoding and memory write\\n";
    } else {
        ++tests_failed;
        std::cout << "[FAIL] SD decoding and memory write\\n";
    }

    // Negative offset: control signals must remain valid.
    dut.instr = encode_s_type(-8, 5, 1, 0b011);
    dut.eval();

    ++tests_run;
    if (dut.mem_write == 1 &&
        dut.mem_read == 0 &&
        dut.reg_write == 0 &&
        dut.uses_rs1 == 1 &&
        dut.uses_rs2 == 1 &&
        dut.illegal_instr == 0) {
        std::cout << "[PASS] SD negative offset controls\\n";
    } else {
        ++tests_failed;
        std::cout << "[FAIL] SD negative offset controls\\n";
    }

    // SW is unsupported: no memory write allowed.
    dut.instr = encode_s_type(16, 5, 1, 0b010);
    dut.eval();

    ++tests_run;
    if (dut.illegal_instr == 1 &&
        dut.mem_write == 0 &&
        dut.reg_write == 0 &&
        dut.uses_rs1 == 0 &&
        dut.uses_rs2 == 0) {
        std::cout << "[PASS] Unsupported SW cannot write memory\\n";
    } else {
        ++tests_failed;
        std::cout << "[FAIL] Unsupported SW cannot write memory\\n";
    }

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
