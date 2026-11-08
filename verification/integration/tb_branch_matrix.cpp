#include "Vrv64_pipeline.h"
#include "verilated.h"
#include <cstdint>
#include <cstdlib>
#include <iostream>

static int checks = 0;
static int failures = 0;

static void check(bool ok, const char* label) {
    ++checks;
    std::cout << (ok ? "[PASS] " : "[FAIL] ")
              << label << '\n';
    if (!ok) ++failures;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    if (argc != 2) return 2;
    int id = std::atoi(argv[1]);
    if (id < 26 || id > 31) return 2;

    Vrv64_pipeline dut;
    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;
    dut.eval();

    for (int i = 0; i < 2; ++i) {
        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.eval();
    }

    dut.reset = 0;
    dut.eval();

    uint64_t last[32] = {};
    int writes[32] = {};
    int traps = 0;

    for (int cycle = 0; cycle < 70; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.trap_valid_o) ++traps;

        if (dut.wb_we && dut.wb_rd != 0) {
            unsigned rd = dut.wb_rd;
            ++writes[rd];
            last[rd] = dut.wb_data;

            std::cout << "[WB] cycle=" << cycle
                      << " x" << rd
                      << "=" << static_cast<int64_t>(dut.wb_data)
                      << '\n';
        }

        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.eval();
    }

    std::cout << "\nPROGRAM_ID=" << id << '\n';
    check(traps == 0, "No unexpected memory traps");

    if (id == 31) {
        check(writes[1] == 4, "Loop initializes and increments x1 three times");
        check(last[1] == 3, "Loop terminates with x1=3");
        check(writes[2] == 1 && last[2] == 3, "Loop bound x2=3");
        check(writes[3] == 1 && last[3] == 99, "Instruction after loop executes");
        check(writes[4] == 1 && last[4] == 7, "Following instruction executes");
    } else {
        int64_t x1 = 5, x2 = 6;
        if (id == 27) { x1 = -1; x2 = 1; }
        if (id == 28) { x1 = 1; x2 = -1; }
        if (id == 29) { x1 = 1; x2 = -1; }
        if (id == 30) { x1 = -1; x2 = 1; }

        check(writes[1] == 1 &&
              last[1] == static_cast<uint64_t>(x1),
              "x1 initialized correctly");
        check(writes[2] == 1 &&
              last[2] == static_cast<uint64_t>(x2),
              "x2 initialized correctly");
        check(writes[3] == 0, "Taken branch squashes x3");
        check(writes[4] == 1 && last[4] == 7,
              "Target x4 executes exactly once");
        check(writes[5] == 1 && last[5] == 8,
              "Target x5 executes exactly once");
    }

    std::cout << "Tests run: " << checks
              << "\nTests failed: " << failures << '\n';

    dut.final();
    return failures ? 1 : 0;
}
