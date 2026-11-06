#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
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

static void tick(Vrv64_pipeline& dut) {
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

    bool seen[32] = {};
    uint64_t values[32] = {};
    bool unexpected_write = false;
    bool duplicate_write = false;

    for (int cycle = 0; cycle < 35; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.wb_we) {
            const unsigned rd = dut.wb_rd;
            const uint64_t data = dut.wb_data;

            std::cout << "[WB] cycle=" << cycle
                      << " rd=x" << rd
                      << " data=" << data << '\n';

            if (rd == 1 || rd == 5 || rd == 6 ||
                rd == 7 || rd == 8) {
                if (seen[rd]) {
                    duplicate_write = true;
                }
                seen[rd] = true;
                values[rd] = data;
            } else if (rd != 0) {
                unexpected_write = true;
            }
        }

        dut.clk = 1;
        dut.eval();
        dut.clk = 0;
        dut.eval();
    }

    check(seen[1] && values[1] == 80,
          "Base register x1 = 80");

    check(seen[5] && values[5] == 42,
          "Store data register x5 = 42");

    check(seen[6] && values[6] == 42,
          "LD with positive offset +8");

    check(seen[7] && values[7] == 42,
          "LD with negative offset -8");

    check(seen[8] && values[8] == 84,
          "ADD combines both loaded values");

    check(!unexpected_write,
          "No unexpected register writes");

    check(!duplicate_write,
          "No duplicate register writes");

    std::cout << "\nTests run: " << checks
              << "\nTests failed: " << failures << '\n';

    dut.final();
    return failures == 0 ? 0 : 1;
}
