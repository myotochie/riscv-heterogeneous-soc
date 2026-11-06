#include "Vrv64_pipeline.h"
#include "Vrv64_pipeline___024root.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline dut;

    constexpr uint32_t CSRRS = 0x305022F3;
    constexpr uint32_t ADDI  = 0x00428313;
    constexpr uint64_t OLD_MTVEC = 0x80000100ULL;

    int tests = 0;
    int failures = 0;

    auto check = [&](bool ok, const char* name) {
        ++tests;
        std::printf("[%s] %s\n", ok ? "PASS" : "FAIL", name);
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

    dut.reset = 0;
    dut.eval();

    bool saw_addi_in_ex = false;
    bool saw_csr_in_wb = false;
    bool saw_forward_01 = false;
    bool saw_correct_wb_data = false;
    bool saw_correct_x6 = false;

    for (int cycle = 0; cycle < 30; ++cycle) {
        dut.clk = 0;
        dut.eval();

        const uint32_t ex_instr =
            dut.rootp->rv64_pipeline__DOT__u_frontend__DOT__id_ex_instr;

        const unsigned forward_a =
            dut.rootp->rv64_pipeline__DOT__u_frontend__DOT__forward_a;

        if (ex_instr == ADDI) {
            saw_addi_in_ex = true;

            std::printf(
                "[EX] cycle=%d instr=0x%08x forward_a=%u "
                "mem_wb_instr=0x%08x wb_data=0x%llx\n",
                cycle,
                ex_instr,
                forward_a,
                dut.mem_wb_instr,
                (unsigned long long)dut.wb_data
            );

            if (dut.mem_wb_valid && dut.mem_wb_instr == CSRRS) {
                saw_csr_in_wb = true;

                if (forward_a == 1)
                    saw_forward_01 = true;

                if (dut.wb_data == OLD_MTVEC)
                    saw_correct_wb_data = true;
            }
        }

        if (dut.wb_we && dut.wb_rd == 6 &&
            dut.wb_data == OLD_MTVEC + 4) {
            saw_correct_x6 = true;
        }

        dut.clk = 1;
        dut.eval();
    }

    check(saw_addi_in_ex, "ADDI observed in EX");
    check(saw_csr_in_wb, "CSRRS simultaneously observed in MEM/WB");
    check(saw_forward_01, "forward_a selects MEM/WB (01)");
    check(saw_correct_wb_data, "MEM/WB provides old mtvec");
    check(saw_correct_x6, "x6 receives old mtvec + 4");

    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
