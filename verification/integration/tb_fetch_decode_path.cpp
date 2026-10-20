#include "Vfetch_decode_path.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(bool condition, const char* name) {
    ++tests_run;
    if (condition) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name << '\n';
    }
}

void tick(Vfetch_decode_path& dut) {
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

    constexpr uint64_t BASE = UINT64_C(0x80000000);

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;
    dut.wb_we = 0;
    dut.wb_rd = 0;
    dut.wb_data = 0;
    dut.eval();

    // Reset initializes PC and invalidates pipeline registers.
    tick(dut);

    check(
        dut.pc_value == BASE &&
        dut.if_id_valid == 0 &&
        dut.id_ex_valid == 0,
        "reset initializes fetch and decode pipeline"
    );

    dut.reset = 0;

    // Cycle 1: first instruction enters IF/ID.
    tick(dut);

    check(
        dut.if_id_valid == 1 &&
        dut.if_id_pc == BASE &&
        dut.if_id_instr == 0x00500093 &&
        dut.id_ex_valid == 0,
        "cycle 1: ADDI x1 enters IF/ID"
    );

    // Cycle 2: first instruction enters ID/EX.
    tick(dut);

    check(
        dut.id_ex_valid == 1 &&
        dut.id_ex_pc == BASE &&
        dut.id_ex_instr == 0x00500093 &&
        dut.id_ex_rd_idx == 1 &&
        dut.id_ex_rs1_value == 0 &&
        dut.id_ex_immediate == 5 &&
        dut.id_ex_reg_write == 1 &&
        dut.id_ex_alu_src == 1 &&
        dut.id_ex_illegal_instr == 0 &&
        dut.if_id_instr == 0x00700113,
        "cycle 2: ADDI x1 enters ID/EX"
    );

    // Cycle 3: second instruction enters ID/EX.
    tick(dut);

    check(
        dut.id_ex_valid == 1 &&
        dut.id_ex_pc == BASE + 4 &&
        dut.id_ex_instr == 0x00700113 &&
        dut.id_ex_rd_idx == 2 &&
        dut.id_ex_immediate == 7,
        "cycle 3: ADDI x2 enters ID/EX"
    );

    // Cycle 4: third instruction enters ID/EX.
    tick(dut);

    check(
        dut.id_ex_valid == 1 &&
        dut.id_ex_pc == BASE + 8 &&
        dut.id_ex_instr == 0x00900193 &&
        dut.id_ex_rd_idx == 3 &&
        dut.id_ex_immediate == 9,
        "cycle 4: ADDI x3 enters ID/EX"
    );

    // Stall must preserve both pipeline registers and PC.
    const uint64_t held_pc = dut.pc_value;
    const uint64_t held_id_ex_pc = dut.id_ex_pc;
    const uint32_t held_id_ex_instr = dut.id_ex_instr;
    const uint32_t held_if_id_instr = dut.if_id_instr;

    dut.stall = 1;
    tick(dut);

    check(
        dut.pc_value == held_pc &&
        dut.id_ex_pc == held_id_ex_pc &&
        dut.id_ex_instr == held_id_ex_instr &&
        dut.if_id_instr == held_if_id_instr,
        "stall holds PC, IF/ID and ID/EX"
    );

    // Flush has priority over stall for pipeline registers.
    dut.flush = 1;
    tick(dut);

    check(
        dut.if_id_valid == 0 &&
        dut.id_ex_valid == 0 &&
        dut.id_ex_reg_write == 0,
        "flush invalidates IF/ID and ID/EX during stall"
    );

    // Resume normal operation.
    dut.flush = 0;
    dut.stall = 0;
    tick(dut);

    check(
        dut.if_id_valid == 1 &&
        dut.id_ex_valid == 0,
        "pipeline resumes after flush"
    );

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
