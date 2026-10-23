
#include "Vpipeline_id_ex.h"
#include <cstdlib>
#include <iostream>

static int tests_passed = 0;

static void check(bool condition, const char* message) {
    if (!condition) {
        std::cerr << "[FAIL] " << message << '\n';
        std::exit(1);
    }
    ++tests_passed;
}

static void tick(Vpipeline_id_ex& dut) {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    dut.clk = 0;
    dut.eval();
}

static void set_inputs(Vpipeline_id_ex& dut) {
    dut.pc_in = 0x80000100ULL;
    dut.instr_in = 0x002081B3;
    dut.rs1_value_in = 0x1111;
    dut.rs2_value_in = 0x2222;
    dut.immediate_in = 0x3333;

    dut.rs1_idx_in = 1;
    dut.rs2_idx_in = 2;
    dut.rd_idx_in = 3;

    dut.alu_op_in = 1; // ALU_SUB
    dut.reg_write_in = 1;
    dut.mem_read_in = 1;
    dut.alu_src_in = 1;
    dut.illegal_instr_in = 0;
    dut.valid_in = 1;
}

static void check_cleared(Vpipeline_id_ex& dut, const char* message) {
    check(dut.valid_out == 0, message);
    check(dut.reg_write_out == 0, "reg_write cleared");
    check(dut.mem_read_out == 0, "mem_read cleared");
    check(dut.alu_src_out == 0, "alu_src cleared");
    check(dut.illegal_instr_out == 0, "illegal_instr cleared");
    check(dut.pc_out == 0, "PC cleared");
    check(dut.instr_out == 0x00000013, "NOP inserted");
    check(dut.rs1_value_out == 0, "rs1 value cleared");
    check(dut.rs2_value_out == 0, "rs2 value cleared");
    check(dut.immediate_out == 0, "immediate cleared");
    check(dut.rs1_idx_out == 0, "rs1 index cleared");
    check(dut.rs2_idx_out == 0, "rs2 index cleared");
    check(dut.rd_idx_out == 0, "rd index cleared");
    check(dut.alu_op_out == 0, "ALU operation reset to ADD");
}

int main() {
    Vpipeline_id_ex dut;

    // Test 1: reset clears the pipeline register.
    dut.reset = 1;
    dut.flush = 0;
    dut.stall = 0;
    set_inputs(dut);
    tick(dut);
    check_cleared(dut, "reset invalidates the register");

    // Test 2: capture all input data and control signals.
    dut.reset = 0;
    set_inputs(dut);
    tick(dut);

    check(dut.pc_out == 0x80000100ULL, "PC captured");
    check(dut.instr_out == 0x002081B3, "instruction captured");
    check(dut.rs1_value_out == 0x1111, "rs1 value captured");
    check(dut.rs2_value_out == 0x2222, "rs2 value captured");
    check(dut.immediate_out == 0x3333, "immediate captured");
    check(dut.rs1_idx_out == 1, "rs1 index captured");
    check(dut.rs2_idx_out == 2, "rs2 index captured");
    check(dut.rd_idx_out == 3, "rd index captured");
    check(dut.alu_op_out == 1, "ALU_SUB captured");
    check(dut.reg_write_out == 1, "reg_write captured");
    check(dut.mem_read_out == 1, "mem_read captured");
    check(dut.alu_src_out == 1, "alu_src captured");
    check(dut.illegal_instr_out == 0, "illegal flag captured");
    check(dut.valid_out == 1, "valid captured");

    // Test 3: stall holds every output.
    dut.stall = 1;
    dut.pc_in = 0xDEADBEEF;
    dut.instr_in = 0xFFFFFFFF;
    dut.rs1_value_in = 0xAAAA;
    dut.rs2_value_in = 0xBBBB;
    dut.immediate_in = 0xCCCC;
    dut.rs1_idx_in = 10;
    dut.rs2_idx_in = 11;
    dut.rd_idx_in = 12;
    dut.alu_op_in = 0;
    dut.reg_write_in = 0;
    dut.mem_read_in = 0;
    dut.alu_src_in = 0;
    dut.illegal_instr_in = 1;
    dut.valid_in = 0;
    tick(dut);

    check(dut.pc_out == 0x80000100ULL, "stall holds PC");
    check(dut.instr_out == 0x002081B3, "stall holds instruction");
    check(dut.rs1_value_out == 0x1111, "stall holds rs1 value");
    check(dut.rs2_value_out == 0x2222, "stall holds rs2 value");
    check(dut.immediate_out == 0x3333, "stall holds immediate");
    check(dut.rs1_idx_out == 1, "stall holds rs1 index");
    check(dut.rs2_idx_out == 2, "stall holds rs2 index");
    check(dut.rd_idx_out == 3, "stall holds rd index");
    check(dut.alu_op_out == 1, "stall holds ALU operation");
    check(dut.reg_write_out == 1, "stall holds reg_write");
    check(dut.mem_read_out == 1, "stall holds mem_read");
    check(dut.alu_src_out == 1, "stall holds alu_src");
    check(dut.illegal_instr_out == 0, "stall holds illegal flag");
    check(dut.valid_out == 1, "stall holds valid");

    // Test 4: flush overrides stall and inserts a bubble.
    dut.flush = 1;
    tick(dut);
    check_cleared(dut, "flush overrides stall");

    // Test 5: reset has priority over flush.
    set_inputs(dut);
    dut.reset = 1;
    dut.flush = 1;
    dut.stall = 0;
    tick(dut);
    check_cleared(dut, "reset has priority over flush");

    // Test 6: invalid input propagates a bubble and disables writes.
    dut.reset = 0;
    dut.flush = 0;
    dut.stall = 0;
    set_inputs(dut);
    dut.valid_in = 0;
    dut.reg_write_in = 1;
    dut.illegal_instr_in = 1;
    tick(dut);

    check(dut.valid_out == 0, "invalid input remains invalid");
    check(dut.reg_write_out == 0, "invalid input disables reg_write");
    check(dut.mem_read_out == 0, "invalid input disables mem_read");
    check(dut.illegal_instr_out == 0,
          "invalid input disables illegal flag");
    check(dut.instr_out == 0x002081B3,
          "instruction data may be captured for invalid input");

    std::cout << "[PASS] pipeline_id_ex: "
              << tests_passed << " checks passed\n";

    dut.final();
    return 0;
}
