#include "Vrv64_pipeline.h"
#include "Vrv64_pipeline___024root.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline dut;

    constexpr uint32_t MRET = 0x30200073;
    constexpr uint32_t SD   = 0x0041B023;

    constexpr uint64_t FAULT_PC  = 0x8000002CULL;
    constexpr uint64_t RESUME_PC = 0x80000030ULL;
    constexpr uint64_t ADDRESS   = 0x80ULL;

    int tests = 0;
    int failures = 0;

    auto check = [&](bool result, const char* name) {
        ++tests;
        std::printf("[%s] %s\n",
                    result ? "PASS" : "FAIL", name);
        if (!result) ++failures;
    };

    auto tick = [&]() {
        dut.clk = 1;
        dut.eval();
        dut.clk = 0;
        dut.eval();
    };

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;
    dut.eval();

    for (int i = 0; i < 3; ++i)
        tick();

    dut.reset = 0;
    dut.eval();

    int trap_count = 0;
    int mret_count = 0;
    int sentinel_reads = 0;
    int corrupted_reads = 0;
    int x7_count = 0;
    int x8_count = 0;

    bool collision = false;
    bool correct_address = false;
    bool correct_store_data = false;
    bool correct_trap = false;
    bool correct_redirect = false;
    bool correct_mstatus = false;
    bool forbidden_store_committed = false;

    for (int cycle = 0; cycle < 45; ++cycle) {
        dut.clk = 0;
        dut.eval();

        if (dut.trap_valid_o) {
            ++trap_count;
            correct_trap =
                dut.trap_epc_o == FAULT_PC &&
                dut.trap_cause_o == 4 &&
                dut.trap_tval_o == 65;
        }

        const bool mret_now =
            dut.mem_wb_valid && dut.mem_wb_instr == MRET;

        if (mret_now) {
            ++mret_count;

            const bool store_in_mem =
                dut.rootp->rv64_pipeline__DOT__ex_mem_instr == SD;

            const uint64_t address =
                dut.rootp->rv64_pipeline__DOT__ex_mem_alu_result;

            const uint64_t store_data =
                dut.rootp->rv64_pipeline__DOT__ex_mem_rs2_value;

            if (store_in_mem) {
                collision = true;
                correct_address = (address == ADDRESS);
                correct_store_data = (store_data == 99);

                std::printf(
                    "[COLLISION] cycle=%d MRET in WB, SD in MEM "
                    "addr=0x%llx data=%llu\n",
                    cycle,
                    (unsigned long long)address,
                    (unsigned long long)store_data
                );
            }
        }

        if (dut.wb_we) {
            if (dut.wb_rd == 12) {
                std::printf(
                    "[RAM READBACK] x12=%llu\n",
                    (unsigned long long)dut.wb_data
                );

                if (dut.wb_data == 42)
                    ++sentinel_reads;

                if (dut.wb_data == 99)
                    ++corrupted_reads;
            }

            if (dut.wb_rd == 7 && dut.wb_data == 7)
                ++x7_count;

            if (dut.wb_rd == 8 && dut.wb_data == 8)
                ++x8_count;
        }

        if (mret_now &&
            dut.rootp->rv64_pipeline__DOT__ex_mem_mem_write &&
            !collision) {
            forbidden_store_committed = true;
        }

        tick();

        if (mret_now) {
            std::printf(
                "[POST-MRET] pc=0x%llx mstatus=0x%llx\n",
                (unsigned long long)dut.pc_value,
                (unsigned long long)dut.csr_mstatus_o
            );

            correct_redirect =
                dut.pc_value == RESUME_PC;

            correct_mstatus =
                (dut.csr_mstatus_o & (1ULL << 3)) != 0 &&
                (dut.csr_mstatus_o & (1ULL << 7)) != 0;
        }
    }

    check(trap_count == 1, "Exactly one exception");
    check(correct_trap, "Correct initial exception");
    check(mret_count == 1, "MRET retires once");
    check(collision, "Younger SD is in MEM during MRET WB");
    check(correct_address, "Store target is aligned RAM address 0x80");
    check(correct_store_data, "Younger store carries forbidden value 99");
    check(correct_redirect, "MRET redirects to resume PC");
    check(correct_mstatus, "MRET restores mstatus");
    check(sentinel_reads == 1, "Memory still contains sentinel 42");
    check(corrupted_reads == 0, "Forbidden value 99 never read back");
    check(x7_count == 1, "Program resumes at x7");
    check(x8_count == 1, "Program continues to x8");

    std::printf("---------------------------------\n");
    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
