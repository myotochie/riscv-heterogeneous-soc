
#include "Vpipeline_if_id.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void tick(Vpipeline_if_id& dut) {
    dut.clk = 0;
    dut.eval();

    dut.clk = 1;
    dut.eval();

    dut.clk = 0;
    dut.eval();
}

void check(
    Vpipeline_if_id& dut,
    uint64_t expected_pc,
    uint32_t expected_instr,
    bool expected_valid,
    const char* name
) {
    ++tests_run;

    const bool pass =
        dut.pc_out == expected_pc &&
        dut.instr_out == expected_instr &&
        dut.valid_out == expected_valid;

    if (pass) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | pc=0x" << std::hex << dut.pc_out
                  << " expected_pc=0x" << expected_pc
                  << " instr=0x" << dut.instr_out
                  << " expected_instr=0x" << expected_instr
                  << std::dec
                  << " valid=" << static_cast<int>(dut.valid_out)
                  << " expected_valid=" << expected_valid
                  << '\n';
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vpipeline_if_id dut{};

    constexpr uint32_t NOP = 0x00000013;

    // 1. Reset must invalidate the register.
    dut.clk = 0;
    dut.reset = 1;
    dut.flush = 0;
    dut.stall = 0;
    dut.pc_in = 0x80000000ULL;
    dut.instr_in = 0x00500093; // ADDI x1, x0, 5
    dut.valid_in = 1;

    tick(dut);
    check(dut, 0, NOP, false, "Reset invalidates IF/ID");

    // 2. Normal capture.
    dut.reset = 0;
    dut.pc_in = 0x80000000ULL;
    dut.instr_in = 0x00500093;
    dut.valid_in = 1;

    tick(dut);
    check(dut, 0x80000000ULL, 0x00500093, true,
          "Normal capture");

    // 3. Stall must preserve the previous contents.
    dut.stall = 1;
    dut.pc_in = 0x80000004ULL;
    dut.instr_in = 0x00700113; // ADDI x2, x0, 7
    dut.valid_in = 1;

    tick(dut);
    check(dut, 0x80000000ULL, 0x00500093, true,
          "Stall holds previous contents");

    // 4. Flush takes priority over stall.
    dut.flush = 1;
    tick(dut);
    check(dut, 0, NOP, false, "Flush overrides stall");

    // 5. Capture resumes after flush and stall are removed.
    dut.flush = 0;
    dut.stall = 0;
    dut.pc_in = 0x80000008ULL;
    dut.instr_in = 0x00900193; // ADDI x3, x0, 9
    dut.valid_in = 1;

    tick(dut);
    check(dut, 0x80000008ULL, 0x00900193, true,
          "Capture resumes after flush");

    // 6. A bubble can be captured with valid_in=0.
    dut.pc_in = 0x8000000CULL;
    dut.instr_in = NOP;
    dut.valid_in = 0;

    tick(dut);
    check(dut, 0x8000000CULL, NOP, false,
          "Invalid input remains a bubble");

    // 7. Reset overrides flush and stall.
    dut.reset = 1;
    dut.flush = 1;
    dut.stall = 1;

    tick(dut);
    check(dut, 0, NOP, false, "Reset has highest priority");

    std::cout << "\nTests run: " << tests_run
              << "\nTests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
