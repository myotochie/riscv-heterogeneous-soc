#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <cstdlib>
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

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    if (argc < 2) {
        std::cerr << "Usage: test <program_id>\n";
        return 2;
    }

    const int program = std::atoi(argv[1]);

    if (program != 24 && program != 25) {
        std::cerr << "Unsupported program ID\n";
        return 2;
    }

    Vrv64_pipeline dut;

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;
    dut.eval();

    // Synchronous reset.
    for (int i = 0; i < 2; ++i) {
        dut.clk = 1;
        dut.eval();
        dut.clk = 0;
        dut.eval();
    }

    dut.reset = 0;
    dut.eval();

    bool wrote_x1 = false;
    bool wrote_x2 = false;
    bool wrote_x3 = false;
    bool wrote_x4 = false;
    bool wrote_x5 = false;

    uint64_t value_x1 = 0;
    uint64_t value_x2 = 0;
    uint64_t value_x3 = 0;
    uint64_t value_x4 = 0;
    uint64_t value_x5 = 0;

    int traps = 0;

    for (int cycle = 0; cycle < 30; ++cycle) {
        // Observe WB before the active clock edge.
        dut.clk = 0;
        dut.eval();

        if (dut.trap_valid_o) {
            ++traps;
        }

        if (dut.wb_we) {
            const uint32_t rd = dut.wb_rd;
            const uint64_t value = dut.wb_data;

            std::cout << "[WB] cycle=" << cycle
                      << " x" << rd
                      << "=" << std::dec << value << '\n';

            switch (rd) {
                case 1: wrote_x1 = true; value_x1 = value; break;
                case 2: wrote_x2 = true; value_x2 = value; break;
                case 3: wrote_x3 = true; value_x3 = value; break;
                case 4: wrote_x4 = true; value_x4 = value; break;
                case 5: wrote_x5 = true; value_x5 = value; break;
                default: break;
            }
        }

        dut.clk = 1;
        dut.eval();
        dut.clk = 0;
        dut.eval();
    }

    std::cout << "\nPROGRAM_ID=" << program << '\n';

    check(traps == 0, "No unexpected memory traps");
    check(wrote_x1 && value_x1 == 5, "x1 initialized to 5");
    check(wrote_x2 && value_x2 == (program == 24 ? 5 : 6),
          "x2 initialized correctly");

    if (program == 24) {
        check(!wrote_x3, "Taken BEQ squashes younger ADDI x3");
    } else {
        check(wrote_x3 && value_x3 == 99,
              "Not-taken BEQ executes ADDI x3");
    }

    check(wrote_x4 && value_x4 == 7, "x4 receives 7");
    check(wrote_x5 && value_x5 == 8, "x5 receives 8");

    std::cout << "\nTests run: " << checks
              << "\nTests failed: " << failures << '\n';

    dut.final();

    return failures ? 1 : 0;
}
