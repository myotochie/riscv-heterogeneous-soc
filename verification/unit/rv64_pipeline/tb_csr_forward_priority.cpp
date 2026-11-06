#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline dut;

    int tests = 0;
    int failures = 0;

    auto check = [&](bool ok, const char* label) {
        ++tests;
        std::printf("[%s] %s\n",
                    ok ? "PASS" : "FAIL", label);
        if (!ok) ++failures;
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
          "Initial mtvec correct");

    dut.reset = 0;
    dut.eval();

    bool saw_x1 = false;
    bool saw_x2 = false;
    bool saw_x7 = false;
    bool saw_trap = false;
    bool saw_x0_write = false;

    bool saw_mtvec_100 = false;
    bool saw_mtvec_200 = false;

    unsigned x6_writes = 0;
    uint64_t x6_value = 0;

    for (int cycle = 0; cycle < 45; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.trap_valid_o)
            saw_trap = true;

        if (dut.wb_we) {
            unsigned rd = dut.wb_rd;
            uint64_t value = dut.wb_data;

            std::printf(
                "[WB] cycle=%d x%u=0x%llx\n",
                cycle, rd,
                (unsigned long long)value
            );

            if (rd == 0)
                saw_x0_write = true;

            if (rd == 1 && value == 0x100ULL)
                saw_x1 = true;

            if (rd == 2 && value == 0x200ULL)
                saw_x2 = true;

            if (rd == 6) {
                ++x6_writes;
                x6_value = value;
            }

            if (rd == 7 && value == 7ULL)
                saw_x7 = true;
        }

        dut.clk = 1;
        dut.eval();

        if (dut.csr_mtvec_o == 0x100ULL)
            saw_mtvec_100 = true;

        if (dut.csr_mtvec_o == 0x200ULL)
            saw_mtvec_200 = true;
    }

    check(saw_x1, "x1 = 0x100");
    check(saw_x2, "x2 = 0x200");
    check(saw_mtvec_100, "First CSR write observed");
    check(saw_mtvec_200, "Second CSR write observed");
    check(x6_writes == 1, "Exactly one x6 writeback");

    std::printf(
        "[CSR PRIORITY] x6=0x%llx expected=0x200\n",
        (unsigned long long)x6_value
    );

    check(x6_writes == 1 && x6_value == 0x200ULL,
          "Newest CSR value forwarded to x6");

    check(dut.csr_mtvec_o == 0x200ULL,
          "Final mtvec = 0x200");

    check(saw_x7, "Independent ALU writeback preserved");
    check(!saw_x0_write, "No GPR writeback to x0");
    check(!saw_trap, "No unexpected trap");

    std::printf("---------------------------------\n");
    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
