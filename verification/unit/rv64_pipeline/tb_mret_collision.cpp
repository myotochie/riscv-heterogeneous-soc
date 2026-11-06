#include "Vrv64_pipeline.h"
#include "Vrv64_pipeline___024root.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline dut;

    constexpr uint64_t FAULT_PC  = 0x8000000CULL;
    constexpr uint64_t RESUME_PC = 0x80000010ULL;
    constexpr uint64_t HANDLER   = 0x80000100ULL;
    constexpr uint32_t MRET      = 0x30200073;

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

    dut.reset = 0;
    dut.eval();

    int trap_count = 0;
    int mret_wb_count = 0;
    int resume_wb_count = 0;

    bool collision_seen = false;
    bool trap_context_ok = false;
    bool entered_handler = false;
    bool trap_status_ok = false;
    bool mret_redirect_ok = false;
    bool mret_status_ok = false;
    bool handler_younger_committed = false;
    bool faulty_load_committed = false;
    bool resumed_x8 = false;

    for (int cycle = 0; cycle < 55; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.pc_value == HANDLER)
            entered_handler = true;

        bool trap_now = dut.trap_valid_o;

        if (trap_now) {
            ++trap_count;

            trap_context_ok =
                dut.trap_epc_o == FAULT_PC &&
                dut.trap_cause_o == 4 &&
                dut.trap_tval_o == 65;
        }

        bool mret_now =
            dut.mem_wb_valid && dut.mem_wb_instr == MRET;

        if (mret_now) {
            ++mret_wb_count;

            const bool younger_load =
                dut.rootp->rv64_pipeline__DOT__ex_mem_instr
                == 0x00013583;

            const bool misaligned_address =
                dut.rootp->rv64_pipeline__DOT__ex_mem_alu_result
                == 0x41ULL;

            if (younger_load && misaligned_address) {
                collision_seen = true;
                std::printf(
                    "[COLLISION] MRET in WB, "
                    "faulting younger LD in MEM\\n"
                );
            }

            std::printf(
                "[MRET] cycle=%d mepc=0x%llx pc=0x%llx\n",
                cycle,
                (unsigned long long)dut.csr_mepc_o,
                (unsigned long long)dut.pc_value
            );
        }

        if (dut.wb_we) {
            std::printf(
                "[WB] cycle=%d x%u=0x%llx\n",
                cycle,
                unsigned(dut.wb_rd),
                (unsigned long long)dut.wb_data
            );

            if (dut.wb_rd == 7 && dut.wb_data == 7)
                ++resume_wb_count;

            if (dut.wb_rd == 8 && dut.wb_data == 8)
                resumed_x8 = true;

            if (dut.wb_rd == 11)
                handler_younger_committed = true;

            if (dut.wb_rd == 6)
                faulty_load_committed = true;
        }

        dut.clk = 1;
        dut.eval();

        if (trap_now) {
            trap_status_ok =
                (dut.csr_mstatus_o & (1ULL << 3)) == 0 &&
                (dut.csr_mstatus_o & (1ULL << 7)) != 0;
        }

        if (mret_now) {
            std::printf(
                "[POST-MRET] pc=0x%llx mstatus=0x%llx\n",
                (unsigned long long)dut.pc_value,
                (unsigned long long)dut.csr_mstatus_o
            );

            if (dut.pc_value == RESUME_PC &&
                dut.csr_mepc_o == RESUME_PC)
                mret_redirect_ok = true;

            if ((dut.csr_mstatus_o & (1ULL << 3)) != 0 &&
                (dut.csr_mstatus_o & (1ULL << 7)) != 0)
                mret_status_ok = true;
        }
    }

    check(collision_seen,
          "MRET WB overlaps younger misaligned LD MEM");
    check(trap_count == 1, "Exactly one exception");
    check(trap_context_ok, "Correct exception context");
    check(entered_handler, "Trap handler reached");
    check(trap_status_ok, "Trap captures MIE into MPIE");
    check(mret_wb_count == 1, "MRET reaches WB exactly once");
    check(mret_redirect_ok, "MRET redirects PC to updated MEPC");
    check(mret_status_ok, "MRET restores MIE and sets MPIE");
    check(resume_wb_count == 1, "Main program resumes at x7");
    check(resumed_x8, "Execution continues after resume");
    check(!handler_younger_committed,
          "Younger handler instruction is squashed");
    check(!faulty_load_committed,
          "Faulting load does not write x6");

    std::printf("---------------------------------\n");
    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
