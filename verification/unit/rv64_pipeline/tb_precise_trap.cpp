#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

static constexpr uint64_t RESET_PC  = 0x80000000ULL;
static constexpr uint64_t FAULT_PC  = 0x80000008ULL;
static constexpr uint64_t TRAP_PC   = 0x80000100ULL;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vrv64_pipeline dut;

    int tests = 0;
    int failures = 0;

    auto check = [&](bool condition, const char* description) {
        ++tests;
        std::printf("[%s] %s\n",
                    condition ? "PASS" : "FAIL",
                    description);
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

    dut.reset = 0;
    dut.eval();

    bool saw_trap = false;
    bool saw_redirect = false;
    bool saw_x1 = false;
    bool saw_x5 = false;
    bool saw_x6 = false;
    bool saw_x7 = false;
    bool saw_x10 = false;
    bool saw_faulting_wb = false;

    uint64_t observed_epc = 0;
    uint64_t observed_cause = 0;
    uint64_t observed_tval = 0;

    for (int cycle = 0; cycle < 50; ++cycle) {
        // Observe combinational outputs before the rising edge.
        dut.clk = 0;
        dut.eval();

        if (dut.trap_valid_o) {
            saw_trap = true;
            observed_epc = dut.trap_epc_o;
            observed_cause = dut.trap_cause_o;
            observed_tval = dut.trap_tval_o;

            std::printf(
                "[TRAP] cycle=%d epc=0x%llx cause=%llu tval=0x%llx\n",
                cycle,
                (unsigned long long)observed_epc,
                (unsigned long long)observed_cause,
                (unsigned long long)observed_tval
            );
        }

        if (dut.pc_value == TRAP_PC) {
            saw_redirect = true;
        }

        if (dut.wb_we) {
            const unsigned rd = dut.wb_rd;
            const uint64_t data = dut.wb_data;

            std::printf(
                "[WB] cycle=%d rd=x%u data=0x%llx\n",
                cycle, rd, (unsigned long long)data
            );

            if (rd == 1 && data == 65) saw_x1 = true;
            if (rd == 5 && data == 99) saw_x5 = true;
            if (rd == 6) saw_x6 = true;
            if (rd == 7) saw_x7 = true;
            if (rd == 10 && data == 123) saw_x10 = true;

            if (dut.mem_wb_valid &&
                dut.mem_wb_pc == FAULT_PC) {
                saw_faulting_wb = true;
            }
        }

        dut.clk = 1;
        dut.eval();
    }

    check(saw_trap, "Exception detected");
    check(observed_epc == FAULT_PC, "Exception PC = 0x80000008");
    check(observed_cause == 4, "Load address misaligned: cause 4");
    check(observed_tval == 0x41, "Fault address = 0x41");
    check(saw_redirect, "PC redirected to 0x80000100");
    check(saw_x1, "Older instruction x1 = 65 committed");
    check(saw_x5, "Older instruction x5 = 99 committed");
    check(!saw_faulting_wb, "Faulting LD did not write back");
    check(!saw_x6, "Younger instruction x6 cancelled");
    check(!saw_x7, "Younger instruction x7 cancelled");
    check(saw_x10, "Trap handler x10 = 123 executed");

    std::printf("\nTests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
