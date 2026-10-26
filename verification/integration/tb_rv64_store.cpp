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
    bool saw_x7 = false;

    bool unexpected_write = false;

    uint64_t x1 = 0;
    uint64_t x5 = 0;
    uint64_t x6 = 0;
    uint64_t x7 = 0;

    for (int cycle = 0; cycle < 25; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.wb_we) {
            const uint32_t rd = dut.wb_rd;
            const uint64_t data = dut.wb_data;

            std::cout << "[WB] cycle=" << cycle
                      << " rd=x" << rd
                      << " data=" << data << '\n';

            switch (rd) {
                case 1:
                    saw_x1 = true;
                    x1 = data;
                    break;

                case 5:
                    saw_x5 = true;
                    x5 = data;
                    break;

                case 6:
                    saw_x6 = true;
                    x6 = data;
                    break;

                case 7:
                    saw_x7 = true;
                    x7 = data;
                    break;

                default:
                    if (rd != 0) {
                        unexpected_write = true;
                    }
                    break;
            }
        }

        dut.clk = 1;
        dut.eval();

        dut.clk = 0;
        dut.eval();
    }

    check(saw_x1, "ADDI writes x1");
    check(saw_x1 && x1 == 64, "x1 contains address 64");

    check(saw_x5, "ADDI writes x5");
    check(saw_x5 && x5 == 21, "x5 contains store data 21");

    check(saw_x6, "LD writes x6");
    check(saw_x6 && x6 == 21, "LD reads value written by SD");

    check(saw_x7, "ADD writes x7");
    check(saw_x7 && x7 == 42, "ADD produces result 42");

    check(!unexpected_write, "No unexpected register writes");

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
