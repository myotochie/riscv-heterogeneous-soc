
#include "Vbranch_target.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(
    Vbranch_target& dut,
    uint64_t pc,
    uint32_t instr,
    uint64_t rs1,
    uint8_t kind,
    uint64_t expected,
    const char* name
) {
    dut.pc = pc;
    dut.instr = instr;
    dut.rs1_value = rs1;
    dut.target_kind = kind;
    dut.eval();

    ++tests_run;
    const uint64_t actual = dut.target;

    if (actual == expected) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | expected=0x" << std::hex << expected
                  << " actual=0x" << actual << std::dec << '\n';
    }
}

// B-type encoder: imm is a signed byte displacement.
uint32_t encode_b_type(int32_t imm) {
    const uint32_t v = static_cast<uint32_t>(imm);
    return (((v >> 12) & 0x1) << 31)
         | (((v >> 5)  & 0x3F) << 25)
         | (((v >> 1)  & 0xF) << 8)
         | (((v >> 11) & 0x1) << 7)
         | 0x63;
}

// J-type encoder: imm is a signed byte displacement.
uint32_t encode_j_type(int32_t imm) {
    const uint32_t v = static_cast<uint32_t>(imm);
    return (((v >> 20) & 0x1) << 31)
         | (((v >> 1)  & 0x3FF) << 21)
         | (((v >> 11) & 0x1) << 20)
         | (((v >> 12) & 0xFF) << 12)
         | 0x6F;
}

uint32_t encode_i_type(int16_t imm) {
    return ((static_cast<uint32_t>(imm) & 0xFFF) << 20) | 0x67;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vbranch_target dut{};

    // B-type: PC + 16.
    check(dut, 0x1000, encode_b_type(16), 0, 0,
          0x1010, "B-type positive offset");

    // B-type: PC - 4.
    check(dut, 0x1000, encode_b_type(-4), 0, 0,
          0x0FFC, "B-type negative offset");

    // J-type: PC + 2048.
    check(dut, 0x1000, encode_j_type(2048), 0, 1,
          0x1800, "J-type positive offset");

    // J-type: PC - 8.
    check(dut, 0x1000, encode_j_type(-8), 0, 1,
          0x0FF8, "J-type negative offset");

    // JALR: (rs1 + immediate) with bit 0 cleared.
    check(dut, 0x1000, encode_i_type(12), 0x2001, 2,
          0x200C, "JALR clears target bit 0");

    // Default kind: return the current PC.
    check(dut, 0x1234, 0, 0, 3,
          0x1234, "Invalid kind returns PC");

    std::cout << "\nTests run: " << tests_run
              << "\nTests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
