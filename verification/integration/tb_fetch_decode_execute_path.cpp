#include "Vfetch_decode_execute_path.h"
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

void tick(Vfetch_decode_execute_path& dut) {
    dut.clk = 0;
    dut.eval();

    dut.clk = 1;
    dut.eval();

    dut.clk = 0;
    dut.eval();
}

void check_ex_mem(
    Vfetch_decode_execute_path& dut,
    uint64_t expected_pc,
    uint32_t expected_instr,
    uint64_t expected_result,
    uint8_t expected_rd,
    const char* name
) {
    check(
        dut.ex_mem_valid == 1 &&
        dut.ex_mem_pc == expected_pc &&
        dut.ex_mem_instr == expected_instr &&
        dut.ex_mem_alu_result == expected_result &&
        dut.ex_mem_rd_idx == expected_rd &&
        dut.ex_mem_reg_write == 1 &&
        dut.ex_mem_illegal_instr == 0,
        name
    );
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vfetch_decode_execute_path dut{};

    constexpr uint64_t BASE = UINT64_C(0x80000000);

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
    dut.eval();

    tick(dut);

    check(
        dut.pc_value == BASE &&
        dut.ex_mem_valid == 0 &&
        dut.ex_mem_reg_write == 0,
        "reset initializes pipeline"
    );

    dut.reset = 0;

    // Cycle 1: first instruction enters IF/ID.
    tick(dut);
    check(
        dut.ex_mem_valid == 0,
        "cycle 1: EX/MEM remains invalid"
    );

    // Cycle 2: first instruction enters ID/EX.
    tick(dut);
    check(
        dut.ex_mem_valid == 0,
        "cycle 2: EX/MEM remains invalid"
    );

    // Cycle 3: first instruction reaches EX/MEM.
    tick(dut);
    check_ex_mem(
        dut, BASE, 0x00500093, 5, 1,
        "cycle 3: ADDI x1 produces 5"
    );

    // Cycle 4: second instruction reaches EX/MEM.
    tick(dut);
    check_ex_mem(
        dut, BASE + 4, 0x00700113, 7, 2,
        "cycle 4: ADDI x2 produces 7"
    );

    // Cycle 5: third instruction reaches EX/MEM.
    tick(dut);
    check_ex_mem(
        dut, BASE + 8, 0x00900193, 9, 3,
        "cycle 5: ADDI x3 produces 9"
    );

    // Stall holds the current pipeline state.
    const uint64_t held_pc = dut.pc_value;
    const uint64_t held_ex_mem_pc = dut.ex_mem_pc;
    const uint64_t held_result = dut.ex_mem_alu_result;
    const uint32_t held_instr = dut.ex_mem_instr;

    dut.stall = 1;
    tick(dut);

    check(
        dut.pc_value == held_pc &&
        dut.ex_mem_pc == held_ex_mem_pc &&
        dut.ex_mem_alu_result == held_result &&
        dut.ex_mem_instr == held_instr &&
        dut.ex_mem_valid == 1,
        "stall holds PC and EX/MEM"
    );

    // Flush must invalidate EX/MEM even during stall.
    dut.flush = 1;
    tick(dut);

    check(
        dut.ex_mem_valid == 0 &&
        dut.ex_mem_reg_write == 0 &&
        dut.ex_mem_alu_result == 0,
        "flush clears EX/MEM during stall"
    );

    // Resume normal operation.
    dut.flush = 0;
    dut.stall = 0;
    tick(dut);

    check(
        dut.ex_mem_valid == 0,
        "pipeline resumes with an empty EX/MEM"
    );

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
