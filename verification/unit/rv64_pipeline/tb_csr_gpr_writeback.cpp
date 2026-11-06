#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline dut;

    int tests = 0;
    int failures = 0;

    auto check = [&](bool condition, const char* label) {
        ++tests;
        std::printf("[%s] %s\n",
                    condition ? "PASS" : "FAIL", label);
        if (!condition) ++failures;
    };

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;
    dut.eval();

    for (int i = 0; i < 3; ++i) {
        dut.clk = 1;
        dut.eval();
        dut.clk = 0;
        dut.eval();
    }

    check(dut.csr_mtvec_o == 0x80000100ULL,
          "Initial mtvec = 0x80000100");

    dut.reset = 0;
    dut.eval();

    bool saw_x1 = false;
    bool saw_x5 = false;
    bool saw_x6 = false;
    bool saw_mtvec_update = false;
    bool saw_trap = false;
    bool saw_x0_write = false;

    int x5_writes = 0;

    for (int cycle = 0; cycle < 40; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.wb_we) {
            unsigned rd = dut.wb_rd;
            uint64_t data = dut.wb_data;

            std::printf(
                "[WB] cycle=%d x%u=0x%llx\n",
                cycle, rd, (unsigned long long)data
            );

            if (rd == 0)
                saw_x0_write = true;

            if (rd == 1 && data == 512ULL)
                saw_x1 = true;

            if (rd == 5) {
                ++x5_writes;
                if (data == 0x80000100ULL)
                    saw_x5 = true;
            }

            if (rd == 6 && data == 7ULL)
                saw_x6 = true;
        }

        if (dut.trap_valid_o)
            saw_trap = true;

        dut.clk = 1;
        dut.eval();

        if (dut.csr_mtvec_o == 0x200ULL)
            saw_mtvec_update = true;
    }

    check(saw_x1, "ADDI writes x1 = 512");
    check(saw_x5, "CSRRW writes old mtvec to x5");
    check(x5_writes == 1, "Exactly one x5 writeback");
    check(saw_mtvec_update, "CSRRW updates mtvec");
    check(dut.csr_mtvec_o == 0x200ULL,
          "Final mtvec = 0x200");
    check(saw_x6, "Normal ALU writeback preserved");
    check(!saw_x0_write, "No writeback to x0");
    check(!saw_trap, "No unexpected memory trap");

    std::printf("---------------------------------\n");
    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
