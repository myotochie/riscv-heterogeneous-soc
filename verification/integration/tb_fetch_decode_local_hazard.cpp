#include "Vfetch_decode_path.h"
#include "verilated.h"

#include <cstdint>
#include <cstdlib>
#include <iostream>

static int checks = 0;
static int failures = 0;

static void check(bool condition, const char* message) {
    ++checks;
    if (condition) {
        std::cout << "[PASS] " << message << '\n';
    } else {
        ++failures;
        std::cerr << "[FAIL] " << message << '\n';
    }
}

static void tick(Vfetch_decode_path& dut) {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    dut.clk = 0;
    dut.eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vfetch_decode_path dut{};

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;

    dut.hazard_stall_pc = 0;
    dut.hazard_stall_if_id = 0;
    dut.hazard_flush_id_ex = 0;

    dut.wb_we = 0;
    dut.wb_rd = 0;
    dut.wb_data = 0;

    tick(dut);

    check(dut.pc_value == 0x80000000ULL,
          "Reset initializes PC");

    check(dut.if_id_valid == 0,
          "Reset invalidates IF/ID");

    check(dut.id_ex_valid == 0,
          "Reset invalidates ID/EX");

    dut.reset = 0;

    // Cycle 1: ADDI x1 enters IF/ID.
    tick(dut);

    check(dut.if_id_valid == 1 &&
          dut.if_id_instr == 0x00500093U,
          "First instruction enters IF/ID");

    // Cycle 2: ADDI x1 enters ID/EX;
    // ADDI x2 enters IF/ID.
    tick(dut);

    check(dut.id_ex_valid == 1 &&
          dut.id_ex_instr == 0x00500093U,
          "First instruction enters ID/EX");

    check(dut.if_id_valid == 1 &&
          dut.if_id_instr == 0x00700113U,
          "Second instruction enters IF/ID");

    const uint64_t pc_before_hazard = dut.pc_value;
    const uint64_t if_id_pc_before_hazard = dut.if_id_pc;
    const uint32_t if_id_instr_before_hazard = dut.if_id_instr;

    // Inject one artificial load-use hazard.
    dut.hazard_stall_pc = 1;
    dut.hazard_stall_if_id = 1;
    dut.hazard_flush_id_ex = 1;

    tick(dut);

    check(dut.pc_value == pc_before_hazard,
          "Hazard stalls PC");

    check(dut.if_id_valid == 1 &&
          dut.if_id_pc == if_id_pc_before_hazard &&
          dut.if_id_instr == if_id_instr_before_hazard,
          "Hazard preserves IF/ID");

    check(dut.id_ex_valid == 0,
          "Hazard injects bubble into ID/EX");

    check(dut.id_ex_reg_write == 0,
          "Bubble cannot write register");

    // Release the hazard.
    dut.hazard_stall_pc = 0;
    dut.hazard_stall_if_id = 0;
    dut.hazard_flush_id_ex = 0;

    tick(dut);

    check(dut.id_ex_valid == 1 &&
          dut.id_ex_instr == 0x00700113U,
          "Preserved instruction enters ID/EX");

    check(dut.if_id_valid == 1 &&
          dut.if_id_instr == 0x00900193U,
          "Fetch resumes with third instruction");

    check(dut.pc_value == pc_before_hazard + 4,
          "PC resumes after hazard");

    std::cout << "\nTests run: " << checks
              << "\nTests failed: " << failures << '\n';

    dut.final();
    return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
