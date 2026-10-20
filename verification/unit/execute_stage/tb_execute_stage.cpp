#include "Vexecute_stage.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

enum AluOp : uint8_t {
    ALU_ADD = 0,
    ALU_SUB = 1,
    ALU_AND = 2,
    ALU_OR  = 3,
    ALU_XOR = 4,
    ALU_SLL = 5,
    ALU_SRL = 6,
    ALU_SRA = 7,
    ALU_SLT = 8,
    ALU_SLTU = 9
};

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
    Vexecute_stage dut{};

    dut.pc_in = UINT64_C(0x80000000);
    dut.instr_in = 0x00500093;
    dut.rs1_value_in = 0;
    dut.rs2_value_in = 99;
    dut.immediate_in = 5;
    dut.rd_idx_in = 1;
    dut.alu_op_in = ALU_ADD;
    dut.alu_src_in = 1;
    dut.reg_write_in = 1;
    dut.illegal_instr_in = 0;
    dut.valid_in = 1;
    dut.eval();

    // 1. ADDI selects immediate instead of rs2.
    check(
        dut.alu_result_out == 5 &&
        dut.rs2_value_out == 99 &&
        dut.rd_idx_out == 1 &&
        dut.reg_write_out == 1,
        "ADDI uses immediate operand"
    );

    // 2. ADD selects register operand.
    dut.rs1_value_in = 42;
    dut.rs2_value_in = 99;
    dut.immediate_in = 1000;
    dut.alu_src_in = 0;
    dut.alu_op_in = ALU_ADD;
    dut.eval();

    check(
        dut.alu_result_out == 141,
        "ADD uses rs2 register operand"
    );

    // 3. SUB.
    dut.alu_op_in = ALU_SUB;
    dut.eval();

    check(
        dut.alu_result_out == UINT64_C(0xFFFFFFFFFFFFFFC7),
        "SUB computes signed negative result"
    );

    // 4. AND.
    dut.rs1_value_in = 0xFF00;
    dut.rs2_value_in = 0x0F0F;
    dut.alu_op_in = ALU_AND;
    dut.eval();

    check(
        dut.alu_result_out == 0x0F00,
        "AND operation"
    );

    // 5. Invalid pipeline slot.
    dut.valid_in = 0;
    dut.eval();

    check(
        dut.valid_out == 0 &&
        dut.reg_write_out == 0 &&
        dut.illegal_instr_out == 0,
        "invalid slot disables register write"
    );

    // 6. Illegal instruction.
    dut.valid_in = 1;
    dut.illegal_instr_in = 1;
    dut.eval();

    check(
        dut.valid_out == 1 &&
        dut.illegal_instr_out == 1 &&
        dut.reg_write_out == 0,
        "illegal instruction disables register write"
    );

    // 7. Memory controls remain disabled.
    check(
        dut.mem_read_out == 0 &&
        dut.mem_write_out == 0 &&
        dut.mem_to_reg_out == 0,
        "memory controls disabled for ALU instructions"
    );

    // 8. Metadata propagation.
    check(
        dut.pc_out == UINT64_C(0x80000000) &&
        dut.instr_out == 0x00500093 &&
        dut.rd_idx_out == 1,
        "PC, instruction and destination propagation"
    );

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
