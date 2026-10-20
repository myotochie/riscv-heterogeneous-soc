#include "Vrv64_pipeline.h"
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

void tick(Vrv64_pipeline& dut) {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    dut.clk = 0;
    dut.eval();
}

void check_wb(
    Vrv64_pipeline& dut,
    uint64_t expected_pc,
    uint32_t expected_instr,
    uint8_t expected_rd,
    uint64_t expected_data,
    const char* name
) {
    check(
        dut.mem_wb_valid == 1 &&
        dut.mem_wb_pc == expected_pc &&
        dut.mem_wb_instr == expected_instr &&
        dut.wb_we == 1 &&
        dut.wb_rd == expected_rd &&
        dut.wb_data == expected_data,
        name
    );
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline dut{};

    constexpr uint64_t BASE = UINT64_C(0x80000000);

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;
    dut.eval();

    tick(dut);

    check(
        dut.pc_value == BASE &&
        dut.mem_wb_valid == 0 &&
        dut.wb_we == 0,
        "reset initializes pipeline and disables WB"
    );

    dut.reset = 0;

    for (int cycle = 1; cycle <= 3; ++cycle) {
        tick(dut);
        check(
            dut.mem_wb_valid == 0 && dut.wb_we == 0,
            "pipeline filling: no premature WB"
        );
    }

    tick(dut);
    check_wb(
        dut, BASE, 0x00500093, 1, 5,
        "cycle 4: ADDI x1 prepares WB value 5"
    );

    tick(dut);
    check_wb(
        dut, BASE + 4, 0x00700113, 2, 7,
        "cycle 5: ADDI x2 prepares WB value 7"
    );

    tick(dut);
    check_wb(
        dut, BASE + 8, 0x00900193, 3, 9,
        "cycle 6: ADDI x3 prepares WB value 9"
    );

    // A global stall must prevent additional writes.
    const uint64_t held_pc = dut.pc_value;
    const uint64_t held_mem_wb_pc = dut.mem_wb_pc;
    const uint64_t held_data = dut.wb_data;

    dut.stall = 1;
    dut.eval();

    check(
        dut.wb_we == 0,
        "stall immediately disables write-back"
    );

    tick(dut);

    check(
        dut.pc_value == held_pc &&
        dut.mem_wb_pc == held_mem_wb_pc &&
        dut.wb_data == held_data &&
        dut.wb_we == 0,
        "stall holds pipeline state without WB"
    );

    // Flush has priority over stall in pipeline registers.
    dut.flush = 1;
    dut.eval();

    check(
        dut.wb_we == 0,
        "flush immediately disables write-back"
    );

    tick(dut);

    check(
        dut.mem_wb_valid == 0 && dut.wb_we == 0,
        "flush invalidates MEM/WB"
    );

    // Reset must also disable writes immediately.
    dut.flush = 0;
    dut.stall = 0;
    dut.reset = 1;
    dut.eval();

    check(
        dut.wb_we == 0,
        "reset disables write-back"
    );

    tick(dut);

    check(
        dut.pc_value == BASE &&
        dut.mem_wb_valid == 0 &&
        dut.wb_we == 0,
        "reset clears pipeline state"
    );

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
