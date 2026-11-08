#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <cstdlib>
#include <iostream>

static int total = 0;
static int failed = 0;

void check(bool ok, const char* label) {
    ++total;
    if (!ok) ++failed;
    std::cout << (ok ? "[PASS] " : "[FAIL] ")
              << label << '\n';
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    if (argc != 2) return 2;
    const int id = std::atoi(argv[1]);
    if (id != 34 && id != 35) return 2;

    Vrv64_pipeline dut;
    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;
    dut.eval();

    for (int i = 0; i < 2; ++i) {
        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.eval();
    }

    dut.reset = 0;
    dut.eval();

    int writes[32] = {};
    uint64_t values[32] = {};
    int traps = 0;
    int mret_events = 0;
    int correct_trap_redirects = 0;
    int correct_mret_redirects = 0;

    const uint64_t handler = 0x80000100ULL;
    const uint64_t resume = 0x80000008ULL;
    const uint32_t mret_instr = 0x30200073u;

    for (int cycle = 0; cycle < 80; ++cycle) {
        dut.clk = 0;
        dut.eval();

        const bool trap_now = dut.trap_valid_o;
        const bool mret_now =
            dut.mem_wb_valid && dut.mem_wb_instr == mret_instr;

        if (trap_now) ++traps;
        if (mret_now) ++mret_events;

        if (dut.wb_we && dut.wb_rd != 0) {
            unsigned rd = dut.wb_rd;
            ++writes[rd];
            values[rd] = dut.wb_data;
            std::cout << "[WB] cycle=" << cycle
                      << " x" << rd << "=" << values[rd] << '\n';
        }

        dut.clk = 1;
        dut.eval();

        if (trap_now && dut.pc_value == handler)
            ++correct_trap_redirects;

        if (mret_now && dut.pc_value == resume)
            ++correct_mret_redirects;

        dut.clk = 0;
        dut.eval();
    }

    std::cout << "\nPROGRAM_ID=" << id << '\n';

    check(traps == 1, "Exactly one memory trap");
    check(correct_trap_redirects == 1,
          "Trap redirects PC to mtvec");
    check(dut.csr_mcause_o == 4,
          "Misaligned LD cause is 4");
    check(dut.csr_mtval_o == 65,
          "Fault address is 65");

    if (id == 34) {
        check(dut.csr_mepc_o == 0x80000008ULL,
              "Trap records faulting LD PC");
        check(writes[7] == 0,
              "Younger sequential instruction canceled");
        check(writes[8] == 0,
              "BEQ target instruction canceled");
        check(writes[10] == 1 && values[10] == 123,
              "Trap handler executes");
        check(mret_events == 0, "No MRET in program 34");
    } else {
        check(mret_events == 1, "MRET retires exactly once");
        check(correct_mret_redirects == 1,
              "MRET redirects to resumed PC");
        check(dut.csr_mepc_o == resume,
              "Handler updates MEPC to resume PC");
        check(writes[7] == 1 && values[7] == 7,
              "Resumed instruction x7 executes");
        check(writes[8] == 1 && values[8] == 8,
              "Resumed instruction x8 executes");
        check(writes[11] == 0,
              "Younger handler instruction canceled");
        check(writes[12] == 0,
              "Competing BEQ target canceled");
    }

    std::cout << "Trap events: " << traps
              << "\nMRET events: " << mret_events
              << "\nTests run: " << total
              << "\nTests failed: " << failed << '\n';

    dut.final();
    return failed ? 1 : 0;
}
