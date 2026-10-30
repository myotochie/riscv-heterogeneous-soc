#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int checks = 0;
static int failures = 0;

static void check(bool condition, const char* name) {
    ++checks;
    std::cout << (condition ? "[PASS] " : "[FAIL] ")
              << name << '\n';
    if (!condition) ++failures;
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

    unsigned writes[32] = {};
    uint64_t values[32] = {};

    for (int cycle = 0; cycle < 25; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.wb_we) {
            const unsigned rd = dut.wb_rd;
            const uint64_t data = dut.wb_data;

            std::cout << "[WB] cycle=" << cycle
                      << " rd=x" << rd
                      << " data=" << data << '\n';

            if (rd < 32) {
                ++writes[rd];
                values[rd] = data;
            }
        }

        dut.clk = 1;
        dut.eval();
        dut.clk = 0;
        dut.eval();
    }

    check(writes[1] == 1 && values[1] == 65,
          "Base address x1 = 65");

    check(writes[5] == 1,
          "Invalid LD does not write x5");

    check(values[5] == 99,
          "x5 retains its previous value");

    check(writes[6] == 1 && values[6] == 7,
          "Following instruction executes");

    unsigned total_writes = 0;
    for (unsigned count : writes)
        total_writes += count;

    check(total_writes == 3,
          "Exactly three architectural register writes");

    std::cout << "\nTests run: " << checks
              << "\nTests failed: " << failures << '\n';

    dut.final();
    return failures == 0 ? 0 : 1;
}
