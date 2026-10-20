#include "Vfetch_path.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

constexpr uint64_t RESET_PC = 0x80000000ULL;
constexpr uint32_t NOP = 0x00000013;

void tick(Vfetch_path& dut) {
    dut.clk = 0;
    dut.eval();

    dut.clk = 1;
    dut.eval();

    dut.clk = 0;
    dut.eval();
}

void check(
    Vfetch_path& dut,
    uint64_t expected_pc,
    uint64_t expected_if_id_pc,
    uint32_t expected_instr,
    bool expected_valid,
    const char* name
) {
    ++tests_run;

    const bool pass =
        dut.pc_value == expected_pc &&
        dut.if_id_pc == expected_if_id_pc &&
        dut.if_id_instr == expected_instr &&
        dut.if_id_valid == expected_valid;

    if (pass) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | pc=0x" << std::hex << dut.pc_value
                  << " expected_pc=0x" << expected_pc
                  << " if_id_pc=0x" << dut.if_id_pc
                  << " expected_if_id_pc=0x" << expected_if_id_pc
                  << " instr=0x" << dut.if_id_instr
                  << " expected_instr=0x" << expected_instr
                  << std::dec
                  << " valid=" << static_cast<int>(dut.if_id_valid)
                  << " expected_valid=" << expected_valid
                  << '\n';
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vfetch_path dut{};

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;

    tick(dut);

    check(
        dut, RESET_PC, 0, NOP, false,
        "Reset initializes PC and invalidates IF/ID"
    );

    // Release reset. PC advances, IF/ID captures the old PC/instruction.
    dut.reset = 0;
    tick(dut);

    check(
        dut, RESET_PC + 4, RESET_PC, 0x00500093, true,
        "Fetch first ADDI"
    );

    tick(dut);

    check(
        dut, RESET_PC + 8, RESET_PC + 4, 0x00700113, true,
        "Fetch second ADDI"
    );

    tick(dut);

    check(
        dut, RESET_PC + 12, RESET_PC + 8, 0x00900193, true,
        "Fetch third ADDI"
    );

    // Stall IF/ID: PC still advances in this initial wrapper.
    // This test documents the current behavior, not the final stall design.
    dut.stall = 1;
    tick(dut);

    check(
        dut, RESET_PC + 12, RESET_PC + 8, 0x00900193, true,
        "IF/ID holds contents during stall"
    );

    // Flush invalidates IF/ID. PC continues sequentially.
    dut.stall = 0;
    dut.flush = 1;
    tick(dut);

    check(
        dut, RESET_PC + 16, 0, NOP, false,
        "Flush invalidates IF/ID"
    );

    std::cout << "\nTests run: " << tests_run
              << "\nTests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
