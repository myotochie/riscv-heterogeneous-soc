#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    if (argc < 2) {
        std::fprintf(stderr, "Usage: %s PROGRAM_ID\n", argv[0]);
        return 2;
    }

    const int program = std::atoi(argv[1]);

    if (program < 10 || program > 13) {
        std::fprintf(stderr, "Invalid PROGRAM_ID\n");
        return 2;
    }

    const uint64_t expected_cause = static_cast<uint64_t>(program - 6);
    const uint64_t expected_tval =
        (program == 10 || program == 12) ? 0x41ULL : 0x1000ULL;

    const uint64_t expected_x1 = expected_tval;
    const uint64_t fault_pc =
        (program == 11 || program == 13)
            ? 0x80000014ULL
            : 0x80000008ULL;
    const uint64_t handler_pc = 0x80000100ULL;

    Vrv64_pipeline dut;

    int tests = 0;
    int failures = 0;

    auto check = [&](bool ok, const char* message) {
        ++tests;
        std::printf("[%s] %s\n", ok ? "PASS" : "FAIL", message);
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

    bool saw_trap = false;
    bool saw_redirect = false;
    bool saw_x1 = false;
    bool saw_x5 = false;
    bool saw_x10 = false;
    bool saw_younger_wb = false;
    bool saw_faulting_wb = false;

    uint64_t observed_epc = 0;
    uint64_t observed_cause = 0;
    uint64_t observed_tval = 0;

    for (int cycle = 0; cycle < 50; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.trap_valid_o) {
            saw_trap = true;
            observed_epc = dut.trap_epc_o;
            observed_cause = dut.trap_cause_o;
            observed_tval = dut.trap_tval_o;

            std::printf(
                "[TRAP] program=%d cycle=%d epc=0x%llx "
                "cause=%llu tval=0x%llx\n",
                program,
                cycle,
                (unsigned long long)observed_epc,
                (unsigned long long)observed_cause,
                (unsigned long long)observed_tval
            );
        }

        if (dut.pc_value == handler_pc) {
            saw_redirect = true;
        }

        if (dut.wb_we) {
            const unsigned rd = dut.wb_rd;
            const uint64_t data = dut.wb_data;

            std::printf(
                "[WB] cycle=%d x%u=0x%llx\n",
                cycle, rd, (unsigned long long)data
            );

            if (rd == 1 && data == expected_x1) saw_x1 = true;
            if (rd == 5 && data == 99) saw_x5 = true;
            if (rd == 10 && data == 123) saw_x10 = true;

            if (rd == 6 || rd == 7 || rd == 8) {
                saw_younger_wb = true;
            }

            if (dut.mem_wb_valid && dut.mem_wb_pc == fault_pc) {
                saw_faulting_wb = true;
            }
        }

        dut.clk = 1;
        dut.eval();
    }

    check(saw_trap, "Trap detected");
    check(observed_epc == fault_pc, "Correct exception PC");
    check(observed_cause == expected_cause, "Correct exception cause");
    check(observed_tval == expected_tval, "Correct fault address");
    check(saw_redirect, "PC redirected to trap handler");
    check(saw_x1, "Older x1 committed");
    check(saw_x5, "Older x5 committed");
    check(!saw_faulting_wb, "Faulting instruction did not write back");
    check(!saw_younger_wb, "Younger instructions cancelled");
    check(saw_x10, "Trap handler executed");

    std::printf("PROGRAM_ID=%d\n", program);
    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
