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

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vrv64_pipeline dut{};

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;

    tick(dut);
    dut.reset = 0;

    bool saw_x1 = false;
    bool saw_x5 = false;
    bool saw_x6 = false;

    uint64_t value_x1 = 0;
    uint64_t value_x5 = 0;
    uint64_t value_x6 = 0;

    // Observe writeback before each active clock edge.
    for (int cycle = 0; cycle < 20; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.wb_we) {
            const uint32_t rd = dut.wb_rd;
            const uint64_t value = dut.wb_data;

            std::cout << "[WB] cycle=" << cycle
                      << " rd=x" << rd
                      << " data=" << value << '\n';

            if (rd == 1) {
                saw_x1 = true;
                value_x1 = value;
            }

            if (rd == 5) {
                saw_x5 = true;
                value_x5 = value;
            }

            if (rd == 6) {
                saw_x6 = true;
                value_x6 = value;
            }
        }

        dut.clk = 1;
        dut.eval();

        dut.clk = 0;
        dut.eval();
    }

    check(saw_x1, "ADDI writes x1");
    check(saw_x1 && value_x1 == 64, "x1 contains address 64");

    check(saw_x5, "LD writes x5");
    check(saw_x5 && value_x5 == 21, "LD loads value 21");

    check(saw_x6, "ADD writes x6");
    check(saw_x6 && value_x6 == 42, "load-use ADD produces 42");

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
