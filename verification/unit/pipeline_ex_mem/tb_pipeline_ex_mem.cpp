
#include "Vpipeline_ex_mem.h"
#include <cstdlib>
#include <iostream>

static int checks = 0;

static void check(bool condition, const char* message) {
    if (!condition) {
        std::cerr << "[FAIL] " << message << '\n';
        std::exit(1);
    }
    ++checks;
}

static void tick(Vpipeline_ex_mem& dut) {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    dut.clk = 0;
    dut.eval();
}

static void set_inputs(Vpipeline_ex_mem& dut) {
    dut.pc_in = 0x80000100ULL;
    dut.instr_in = 0x0020A023;
    dut.alu_result_in = 0x80002000ULL;
    dut.rs2_value_in = 0xDEADBEEFCAFEBABEULL;
    dut.rd_idx_in = 5;

    dut.reg_write_in = 1;
    dut.mem_read_in = 0;
    dut.mem_write_in = 1;
    dut.mem_to_reg_in = 0;
    dut.illegal_instr_in = 0;
    dut.valid_in = 1;
}

static void check_cleared(Vpipeline_ex_mem& dut) {
    check(dut.pc_out == 0, "PC cleared");
    check(dut.instr_out == 0x00000013, "NOP inserted");
    check(dut.alu_result_out == 0, "ALU result cleared");
    check(dut.rs2_value_out == 0, "rs2 value cleared");
    check(dut.rd_idx_out == 0, "rd index cleared");

    check(dut.reg_write_out == 0, "reg_write cleared");
    check(dut.mem_read_out == 0, "mem_read cleared");
    check(dut.mem_write_out == 0, "mem_write cleared");
    check(dut.mem_to_reg_out == 0, "mem_to_reg cleared");
    check(dut.illegal_instr_out == 0, "illegal flag cleared");
    check(dut.valid_out == 0, "valid cleared");
}

int main() {
    Vpipeline_ex_mem dut;

    // Test 1: reset clears every field.
    dut.reset = 1;
    dut.flush = 0;
    dut.stall = 0;
    set_inputs(dut);
    tick(dut);
    check_cleared(dut);

    // Test 2: normal capture of data and control signals.
    dut.reset = 0;
    set_inputs(dut);
    tick(dut);

    check(dut.pc_out == 0x80000100ULL, "PC captured");
    check(dut.instr_out == 0x0020A023, "instruction captured");
    check(dut.alu_result_out == 0x80002000ULL, "ALU result captured");
    check(dut.rs2_value_out == 0xDEADBEEFCAFEBABEULL,
          "store data captured");
    check(dut.rd_idx_out == 5, "rd index captured");
    check(dut.reg_write_out == 1, "reg_write captured");
    check(dut.mem_read_out == 0, "mem_read captured");
    check(dut.mem_write_out == 1, "mem_write captured");
    check(dut.mem_to_reg_out == 0, "mem_to_reg captured");
    check(dut.illegal_instr_out == 0, "illegal flag captured");
    check(dut.valid_out == 1, "valid captured");

    // Test 3: stall holds every output despite changing inputs.
    dut.stall = 1;
    dut.pc_in = 0xDEADBEEF;
    dut.instr_in = 0xFFFFFFFF;
    dut.alu_result_in = 0xAAAAAAAA;
    dut.rs2_value_in = 0xBBBBBBBB;
    dut.rd_idx_in = 12;
    dut.reg_write_in = 0;
    dut.mem_read_in = 1;
    dut.mem_write_in = 0;
    dut.mem_to_reg_in = 1;
    dut.illegal_instr_in = 1;
    dut.valid_in = 0;
    tick(dut);

    check(dut.pc_out == 0x80000100ULL, "stall holds PC");
    check(dut.instr_out == 0x0020A023, "stall holds instruction");
    check(dut.alu_result_out == 0x80002000ULL, "stall holds ALU result");
    check(dut.rs2_value_out == 0xDEADBEEFCAFEBABEULL,
          "stall holds store data");
    check(dut.rd_idx_out == 5, "stall holds rd index");
    check(dut.reg_write_out == 1, "stall holds reg_write");
    check(dut.mem_read_out == 0, "stall holds mem_read");
    check(dut.mem_write_out == 1, "stall holds mem_write");
    check(dut.mem_to_reg_out == 0, "stall holds mem_to_reg");
    check(dut.illegal_instr_out == 0, "stall holds illegal flag");
    check(dut.valid_out == 1, "stall holds valid");

    // Test 4: flush overrides stall and clears memory commands.
    dut.flush = 1;
    tick(dut);
    check_cleared(dut);

    // Test 5: reset has priority over flush.
    set_inputs(dut);
    dut.reset = 1;
    dut.flush = 1;
    dut.stall = 0;
    tick(dut);
    check_cleared(dut);

    // Test 6: invalid input propagates a bubble and disables side effects.
    dut.reset = 0;
    dut.flush = 0;
    dut.stall = 0;
    set_inputs(dut);
    dut.valid_in = 0;
    dut.reg_write_in = 1;
    dut.mem_read_in = 1;
    dut.mem_write_in = 1;
    dut.mem_to_reg_in = 1;
    dut.illegal_instr_in = 1;
    tick(dut);

    check(dut.valid_out == 0, "invalid input remains invalid");
    check(dut.reg_write_out == 0, "invalid input disables reg_write");
    check(dut.mem_read_out == 0, "invalid input disables mem_read");
    check(dut.mem_write_out == 0, "invalid input disables mem_write");
    check(dut.mem_to_reg_out == 0, "invalid input disables mem_to_reg");
    check(dut.illegal_instr_out == 0,
          "invalid input disables illegal flag");
    check(dut.instr_out == 0x0020A023,
          "instruction data may be captured for invalid input");

    std::cout << "[PASS] pipeline_ex_mem: "
              << checks << " checks passed\n";

    dut.final();
    return 0;
}
