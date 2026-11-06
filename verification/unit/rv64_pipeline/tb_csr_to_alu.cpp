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

    unsigned x5_writes = 0;
    unsigned x6_writes = 0;
    unsigned x7_writes = 0;

    uint64_t x5_value = 0;
    uint64_t x6_value = 0;
    uint64_t x7_value = 0;

    bool saw_trap = false;

    for (int cycle = 0; cycle < 35; ++cycle) {
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

            if (rd == 5) {
                ++x5_writes;
                x5_value = value;
            }

            if (rd == 6) {
                ++x6_writes;
                x6_value = value;
            }

            if (rd == 7) {
                ++x7_writes;
                x7_value = value;
            }
        }

        dut.clk = 1;
        dut.eval();
    }

    check(x5_writes == 1, "Exactly one x5 writeback");
    check(x5_value == 0x80000100ULL,
          "CSRRS returns initial mtvec");

    check(x6_writes == 1, "Exactly one x6 writeback");

    std::printf(
        "[CSR->ALU] x6 observed=0x%llx expected=0x80000104\n",
        (unsigned long long)x6_value
    );

    check(x6_writes == 1 &&
          x6_value == 0x80000104ULL,
          "CSR-to-ALU RAW dependency resolved");

    check(x7_writes == 1 && x7_value == 7ULL,
          "Independent ALU instruction preserved");

    check(dut.csr_mtvec_o == 0x80000100ULL,
          "CSRRS with rs1=x0 leaves mtvec unchanged");

    check(!saw_trap, "No unexpected memory trap");

    std::printf("---------------------------------\n");
    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
