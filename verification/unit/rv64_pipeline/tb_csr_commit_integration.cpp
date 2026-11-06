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
          "Initial mtvec reset value");

    dut.reset = 0;
    dut.eval();

    bool saw_x1 = false;
    bool saw_csr_commit = false;
    bool saw_unexpected_trap = false;

    for (int cycle = 0; cycle < 35; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.wb_we && dut.wb_rd == 1 &&
            dut.wb_data == 512ULL) {
            saw_x1 = true;
        }

        if (dut.trap_valid_o)
            saw_unexpected_trap = true;

        dut.clk = 1;
        dut.eval();

        if (dut.csr_mtvec_o == 512ULL) {
            saw_csr_commit = true;
            std::printf("[CSR] cycle=%d mtvec=0x%llx\n",
                        cycle,
                        (unsigned long long)dut.csr_mtvec_o);
        }
    }

    check(saw_x1, "ADDI x1,x0,512 committed");
    check(saw_csr_commit, "CSRRW committed to mtvec");
    check(dut.csr_mtvec_o == 512ULL,
          "Final mtvec value correct");
    check(!saw_unexpected_trap,
          "No unexpected memory trap");

    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
