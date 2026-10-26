#include "Vfetch_decode_execute_path.h"
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

static void tick(Vfetch_decode_execute_path& dut) {
    dut.clk = 0;
    dut.eval();

    dut.clk = 1;
    dut.eval();

    dut.clk = 0;
    dut.eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vfetch_decode_execute_path dut{};

    constexpr uint32_t LD  = 0x0000B283U;
    constexpr uint32_t ADD = 0x00228333U;
    constexpr uint32_t ADDI = 0x00900393U;

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;

    dut.wb_we = 0;
    dut.wb_rd = 0;
    dut.wb_data = 0;

    dut.mem_wb_valid = 0;
    dut.mem_wb_reg_write = 0;
    dut.mem_wb_rd_idx = 0;

    tick(dut);

    check(dut.pc_value == 0x80000000ULL,
          "Reset initializes PC");

    check(dut.ex_mem_mem_read == 0 &&
          dut.ex_mem_mem_to_reg == 0,
          "Reset clears EX/MEM memory controls");


    dut.reset = 0;

    // Cycle 1: LD enters IF/ID.
    tick(dut);

    check(dut.pc_value == 0x80000004ULL,
          "PC advances after fetching LD");

    // Cycle 2: LD enters ID/EX, ADD enters IF/ID.
    // The combinational hazard detector now sees LD -> ADD.
    tick(dut);

    check(dut.pc_value == 0x80000008ULL,
          "PC reaches third instruction before hazard stall");

    const uint64_t stalled_pc = dut.pc_value;

    // Cycle 3: hazard automatically stalls fetch/decode
    // and inserts a bubble into ID/EX.
    tick(dut);

    check(dut.pc_value == stalled_pc,
          "Load-use hazard automatically stalls PC");

    check(dut.ex_mem_valid == 1 &&
          dut.ex_mem_instr == LD,
          "LD advances into EX/MEM during hazard");

    check(dut.ex_mem_mem_read == 1 &&
          dut.ex_mem_mem_to_reg == 1,
          "LD propagates memory controls into EX/MEM");


    // Cycle 4: ADD resumes and enters ID/EX.
    tick(dut);

    check(dut.pc_value == stalled_pc + 4,
          "PC resumes after one-cycle hazard");

    check(dut.ex_mem_valid == 0,
          "Bubble reaches EX/MEM after hazard");

    check(dut.ex_mem_mem_read == 0 &&
          dut.ex_mem_mem_to_reg == 0,
          "Hazard bubble clears EX/MEM memory controls");


    // Cycle 5: ADD advances into EX/MEM.
    tick(dut);

    check(dut.ex_mem_valid == 1 &&
          dut.ex_mem_instr == ADD,
          "Dependent ADD advances after the bubble");

    check(dut.ex_mem_mem_read == 0 &&
          dut.ex_mem_mem_to_reg == 0,
          "ADD does not request a memory read");


    // Cycle 6: ADDI advances into EX/MEM.
    tick(dut);

    check(dut.ex_mem_valid == 1 &&
          dut.ex_mem_instr == ADDI,
          "Following ADDI executes without extra stall");

    check(dut.ex_mem_mem_read == 0 &&
          dut.ex_mem_mem_to_reg == 0,
          "ADDI does not request a memory read");


    std::cout << "\nTests run: " << checks
              << "\nTests failed: " << failures << '\n';

    dut.final();
    return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
