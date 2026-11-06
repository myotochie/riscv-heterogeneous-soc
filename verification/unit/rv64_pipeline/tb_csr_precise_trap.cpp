#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline dut;

    constexpr uint32_t CSR_INSN = 0x30509073;
    constexpr uint64_t OLD_MTVEC = 0x80000100ULL;
    constexpr uint64_t NEW_MTVEC = 0x200ULL;
    constexpr uint64_t FAULT_PC = 0x80000014ULL;

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

    check(dut.csr_mtvec_o == OLD_MTVEC,
          "Initial mtvec correct");

    dut.reset = 0;
    dut.eval();

    bool saw_collision = false;
    bool saw_trap = false;
    bool correct_trap_context = false;
    bool csr_preserved_at_trap = false;
    bool saw_new_handler_pc = false;
    bool saw_old_handler_pc = false;
    bool saw_x10 = false;
    bool saw_x11 = false;
    bool saw_faulting_writeback = false;
    bool saw_younger_writeback = false;

    for (int cycle = 0; cycle < 35; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.pc_value == NEW_MTVEC)
            saw_new_handler_pc = true;

        if (dut.pc_value == OLD_MTVEC)
            saw_old_handler_pc = true;

        if (dut.wb_we) {
            std::printf(
                "[WB] cycle=%d x%u=0x%llx\n",
                cycle,
                unsigned(dut.wb_rd),
                (unsigned long long)dut.wb_data
            );

            if (dut.wb_rd == 10 && dut.wb_data == 123)
                saw_x10 = true;

            if (dut.wb_rd == 11 && dut.wb_data == 88)
                saw_x11 = true;

            if (dut.wb_rd == 6)
                saw_faulting_writeback = true;

            if (dut.wb_rd == 7)
                saw_younger_writeback = true;
        }

        const bool trap_now = dut.trap_valid_o;
        const bool csr_in_wb =
            dut.mem_wb_valid && dut.mem_wb_instr == CSR_INSN;

        if (trap_now) {
            saw_trap = true;
            correct_trap_context =
                dut.trap_epc_o == FAULT_PC &&
                dut.trap_cause_o == 4 &&
                dut.trap_tval_o == 0x41ULL;
        }

        if (trap_now && csr_in_wb) {
            saw_collision = true;

            std::printf(
                "[COLLISION] cycle=%d CSR in WB, trap in MEM "
                "mtvec_before=0x%llx\n",
                cycle,
                (unsigned long long)dut.csr_mtvec_o
            );
        }

        dut.clk = 1;
        dut.eval();

        if (trap_now && csr_in_wb) {
            std::printf(
                "[POST-EDGE] mtvec=0x%llx pc=0x%llx\n",
                (unsigned long long)dut.csr_mtvec_o,
                (unsigned long long)dut.pc_value
            );

            csr_preserved_at_trap =
                dut.csr_mtvec_o == NEW_MTVEC;

            if (dut.pc_value == NEW_MTVEC)
                saw_new_handler_pc = true;

            if (dut.pc_value == OLD_MTVEC)
                saw_old_handler_pc = true;
        }
    }

    check(saw_trap, "Memory exception detected");
    check(correct_trap_context,
          "Correct epc, cause and tval");
    check(saw_collision,
          "Older CSR WB coincides with younger MEM trap");
    check(csr_preserved_at_trap,
          "Older CSR commit preserved at trap edge");
    check(dut.csr_mtvec_o == NEW_MTVEC,
          "Final mtvec retains older CSR write");
    check(saw_new_handler_pc,
          "PC redirected to updated mtvec");
    check(saw_x10,
          "New trap handler executed");
    check(!saw_old_handler_pc && !saw_x11,
          "Stale trap handler not selected");
    check(!saw_faulting_writeback,
          "Faulting load cannot write x6");
    check(!saw_younger_writeback,
          "Younger ADDI cannot write x7");

    std::printf("---------------------------------\n");
    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
