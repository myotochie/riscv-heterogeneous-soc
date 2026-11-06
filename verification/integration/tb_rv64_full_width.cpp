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

    bool seen_x1 = false;
    bool seen_x5 = false;
    bool seen_x6 = false;
    bool unexpected_write = false;
    bool duplicate_write = false;

    uint64_t x1 = 0;
    uint64_t x5 = 0;
    uint64_t x6 = 0;

    for (int cycle = 0; cycle < 25; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.wb_we) {
            unsigned rd = dut.wb_rd;
            uint64_t data = dut.wb_data;

            std::cout << "[WB] cycle=" << cycle
                      << " rd=x" << rd
                      << " data=0x" << std::hex << data
                      << std::dec << '\n';

            switch (rd) {
                case 1:
                    duplicate_write |= seen_x1;
                    seen_x1 = true;
                    x1 = data;
                    break;
                case 5:
                    duplicate_write |= seen_x5;
                    seen_x5 = true;
                    x5 = data;
                    break;
                case 6:
                    duplicate_write |= seen_x6;
                    seen_x6 = true;
                    x6 = data;
                    break;
                default:
                    if (rd != 0) unexpected_write = true;
            }
        }

        dut.clk = 1;
        dut.eval();
        dut.clk = 0;
        dut.eval();
    }

    constexpr uint64_t expected = 0x1122334455667788ULL;

    check(seen_x1 && x1 == 64, "Base address x1 = 64");
    check(seen_x5, "First LD writes x5");
    check(seen_x5 && x5 == expected, "First LD preserves 64 bits");
    check(seen_x6, "Second LD writes x6");
    check(seen_x6 && x6 == expected, "LD -> SD -> LD preserves 64 bits");
    check(!unexpected_write, "No unexpected register writes");
    check(!duplicate_write, "No duplicate register writes");

    std::cout << "\nTests run: " << checks
              << "\nTests failed: " << failures << '\n';

    dut.final();
    return failures == 0 ? 0 : 1;
}
