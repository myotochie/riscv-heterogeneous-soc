#include "Vexecute_stage.h"
#include "verilated.h"

#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(bool condition, const char* name) {
    ++tests_run;
    std::cout << (condition ? "[PASS] " : "[FAIL] ")
              << name << '\n';
    if (!condition) ++tests_failed;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vexecute_stage dut{};

    // Initialisation des signaux
    dut.pc_in = 0x80000000ULL;
    dut.instr_in = 0x00000033;
    dut.rs1_value_in = 5;
    dut.rs2_value_in = 7;
    dut.immediate_in = 9;
    dut.rd_idx_in = 3;

    // core_pkg::ALU_ADD = 0
    dut.alu_op_in = 0;
    dut.alu_src_in = 0;
    dut.reg_write_in = 1;
    dut.illegal_instr_in = 0;
    dut.valid_in = 1;

    dut.forward_a_in = 0;
    dut.forward_b_in = 0;
    dut.ex_mem_forward_data_in = 20;
    dut.mem_wb_forward_data_in = 30;

    dut.eval();

    check(dut.alu_result_out == 12,
          "ADD without forwarding: 5 + 7 = 12");

    // Forwarding EX/MEM sur rs1
    dut.forward_a_in = 2;
    dut.eval();

    check(dut.alu_result_out == 27,
          "EX/MEM forwarding on rs1: 20 + 7 = 27");

    // Forwarding MEM/WB sur rs2
    dut.forward_a_in = 0;
    dut.forward_b_in = 1;
    dut.eval();

    check(dut.alu_result_out == 35,
          "MEM/WB forwarding on rs2: 5 + 30 = 35");

    // ADDI : l'immediat reste prioritaire sur rs2
    dut.alu_src_in = 1;
    dut.eval();

    check(dut.alu_result_out == 14,
          "ADDI uses immediate despite rs2 forwarding");

    // La valeur rs2 transmise vers MEM doit rester forwardee
    check(dut.rs2_value_out == 30,
          "Forwarded rs2 propagated to memory interface");

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
