
#include "Vcontrol_flow_unit.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

static constexpr uint64_t RESET_PC = 0x80000000ULL;

void tick(Vcontrol_flow_unit& dut) {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    dut.clk = 0;
    dut.eval();
}

void check_pc(
    Vcontrol_flow_unit& dut,
    uint64_t expected,
    const char* name
) {
    ++tests_run;

    if (dut.pc_value == expected) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | PC=0x" << std::hex << dut.pc_value
                  << " expected=0x" << expected
                  << std::dec << '\n';
    }
}

void clear_instruction(Vcontrol_flow_unit& dut) {
    dut.instr = 0x00000013; // ADDI x0, x0, 0 (NOP)
    dut.rs1_value = 0;
    dut.rs2_value = 0;
    dut.illegal_instr = 0;
    dut.is_branch = 0;
    dut.is_jal = 0;
    dut.is_jalr = 0;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcontrol_flow_unit dut{};

    dut.clk = 0;
    dut.reset = 1;
    clear_instruction(dut);

    tick(dut);
    check_pc(dut, RESET_PC, "Reset loads RESET_PC");

    dut.reset = 0;
    tick(dut);
    check_pc(dut, RESET_PC + 4, "Sequential PC increments by 4");

    // BEQ x1, x2, +8: equal operands -> branch taken.
    clear_instruction(dut);
    dut.instr = 0x00208463;
    dut.rs1_value = 42;
    dut.rs2_value = 42;
    dut.is_branch = 1;

    tick(dut);
    check_pc(dut, RESET_PC + 12, "BEQ taken redirects to PC+8");

    // Next instruction: BEQ x1, x2, +8, unequal operands.
    clear_instruction(dut);
    dut.instr = 0x00208463;
    dut.rs1_value = 42;
    dut.rs2_value = 99;
    dut.is_branch = 1;

    tick(dut);
    check_pc(dut, RESET_PC + 16, "BEQ not taken increments by 4");

    // JAL x0, +8.
    clear_instruction(dut);
    dut.instr = 0x0080006F;
    dut.is_jal = 1;

    tick(dut);
    check_pc(dut, RESET_PC + 24, "JAL redirects to PC+8");

    // JALR x0, 0(x1), with rs1=0x1003.
    // The least significant target bit must be cleared.
    clear_instruction(dut);
    dut.instr = 0x00008067;
    dut.rs1_value = 0x1003;
    dut.is_jalr = 1;

    tick(dut);
    check_pc(dut, 0x1002, "JALR clears target bit 0");

    // An illegal instruction must suppress a requested JAL redirect.
    clear_instruction(dut);
    dut.instr = 0x0080006F;
    dut.is_jal = 1;
    dut.illegal_instr = 1;

    tick(dut);
    check_pc(dut, 0x1006, "Illegal instruction suppresses redirect");

    std::cout << "\nTests run: " << tests_run
              << "\nTests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
