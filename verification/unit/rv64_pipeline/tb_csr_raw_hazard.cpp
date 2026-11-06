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
          "Initial mtvec reset value");

    dut.reset = 0;
    dut.eval();

    bool saw_x1 = false;
    bool saw_x5 = false;
    bool saw_x6 = false;
    bool saw_x7 = false;
    bool saw_trap = false;

    uint64_t x6_value = 0;
    unsigned x6_writes = 0;

    for (int cycle = 0; cycle < 40; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.trap_valid_o)
            saw_trap = true;

        if (dut.wb_we) {
            const unsigned rd = dut.wb_rd;
            const uint64_t data = dut.wb_data;

            std::printf("[WB] cycle=%d x%u=0x%llx\n",
                        cycle, rd,
                        (unsigned long long)data);

            if (rd == 1 && data == 0x200ULL)
                saw_x1 = true;

            if (rd == 5 && data == 0x80000100ULL)
                saw_x5 = true;

            if (rd == 6) {
                saw_x6 = true;
                x6_value = data;
                ++x6_writes;
            }

            if (rd == 7 && data == 7ULL)
                saw_x7 = true;
        }

        dut.clk = 1;
        dut.eval();
    }

    check(saw_x1, "Source register x1 = 0x200");
    check(saw_x5, "CSRRW returns old mtvec in x5");
    check(dut.csr_mtvec_o == 0x200ULL,
          "CSRRW commits new mtvec = 0x200");
    check(saw_x6, "CSRRS writes x6");
    check(x6_writes == 1, "Exactly one x6 writeback");

    if (saw_x6) {
        std::printf(
            "[CSR RAW] x6 observed=0x%llx expected=0x200\n",
            (unsigned long long)x6_value
        );
    }

    check(saw_x6 && x6_value == 0x200ULL,
          "CSR RAW dependency resolved correctly");
    check(saw_x7, "Independent ALU writeback preserved");
    check(!saw_trap, "No unexpected memory trap");

    std::printf("---------------------------------\n");
    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
