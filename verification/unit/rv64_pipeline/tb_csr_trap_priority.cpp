#include "Vcsr_file.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

static constexpr uint16_t MSTATUS = 0x300;
static constexpr uint16_t MTVEC   = 0x305;
static constexpr uint16_t MEPC    = 0x341;
static constexpr uint16_t MCAUSE  = 0x342;
static constexpr uint16_t MTVAL   = 0x343;

static constexpr uint64_t FAULT_PC = 0x80000014ULL;
static constexpr uint64_t CAUSE    = 4;
static constexpr uint64_t BADADDR  = 0x41;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcsr_file dut;

    int tests = 0;
    int failures = 0;

    auto check = [&](bool ok, const char* label) {
        ++tests;
        std::printf("[%s] %s\n",
                    ok ? "PASS" : "FAIL", label);
        if (!ok) ++failures;
    };

    auto tick = [&]() {
        dut.clk = 0;
        dut.eval();
        dut.clk = 1;
        dut.eval();
        dut.clk = 0;
        dut.eval();
    };

    auto reset = [&]() {
        dut.reset = 1;
        dut.trap_valid = 0;
        dut.csr_we = 0;
        dut.mret_valid = 0;
        dut.csr_raddr = 0;
        dut.csr_waddr = 0;
        dut.csr_wdata = 0;
        dut.trap_epc = 0;
        dut.trap_cause = 0;
        dut.trap_tval = 0;
        tick();
        dut.reset = 0;
        dut.eval();
    };

    auto collision = [&](uint16_t addr, uint64_t data) {
        reset();

        dut.csr_we = 1;
        dut.csr_waddr = addr;
        dut.csr_wdata = data;

        dut.trap_valid = 1;
        dut.trap_epc = FAULT_PC;
        dut.trap_cause = CAUSE;
        dut.trap_tval = BADADDR;

        tick();

        dut.csr_we = 0;
        dut.trap_valid = 0;
        dut.eval();
    };

    // 1. Older MEPC write versus younger trap.
    collision(MEPC, 0x400);

    check(dut.mepc_o == FAULT_PC,
          "Trap overrides older MEPC write");
    check(dut.mcause_o == CAUSE,
          "Trap cause preserved with MEPC collision");
    check(dut.mtval_o == BADADDR,
          "Trap address preserved with MEPC collision");

    // 2. Older MCAUSE write versus younger trap.
    collision(MCAUSE, 0x99);

    check(dut.mcause_o == CAUSE,
          "Trap overrides older MCAUSE write");
    check(dut.mepc_o == FAULT_PC,
          "Trap PC preserved with MCAUSE collision");
    check(dut.mtval_o == BADADDR,
          "Trap address preserved with MCAUSE collision");

    // 3. Older MTVAL write versus younger trap.
    collision(MTVAL, 0x1234);

    check(dut.mtval_o == BADADDR,
          "Trap overrides older MTVAL write");
    check(dut.mepc_o == FAULT_PC,
          "Trap PC preserved with MTVAL collision");
    check(dut.mcause_o == CAUSE,
          "Trap cause preserved with MTVAL collision");

    // 4. Older MSTATUS write sets MIE=1, MPIE=0.
    // The younger trap must capture this new MIE in MPIE
    // and then clear MIE.
    collision(MSTATUS, 0x8);

    check((dut.mstatus_o & (1ULL << 3)) == 0,
          "Trap clears MSTATUS.MIE");
    check((dut.mstatus_o & (1ULL << 7)) != 0,
          "MPIE captures older WB MIE=1");
    check(((dut.mstatus_o >> 11) & 3ULL) == 3,
          "Trap sets MSTATUS.MPP=M");
    check(dut.mepc_o == FAULT_PC,
          "Trap PC preserved with MSTATUS collision");

    // 5. Older MSTATUS write clears MIE.
    // MPIE must capture zero rather than the previous value.
    reset();

    dut.csr_we = 1;
    dut.csr_waddr = MSTATUS;
    dut.csr_wdata = 0x8;
    tick();

    dut.csr_wdata = 0x80;
    dut.trap_valid = 1;
    dut.trap_epc = FAULT_PC;
    dut.trap_cause = CAUSE;
    dut.trap_tval = BADADDR;
    tick();

    dut.csr_we = 0;
    dut.trap_valid = 0;
    dut.eval();

    check((dut.mstatus_o & (1ULL << 7)) == 0,
          "MPIE captures older WB MIE=0");
    check((dut.mstatus_o & (1ULL << 3)) == 0,
          "MIE remains cleared after trap");

    // 6. MTVEC write must survive a younger trap.
    collision(MTVEC, 0x200);

    check(dut.mtvec_o == 0x200,
          "Older MTVEC write survives younger trap");
    check(dut.mepc_o == FAULT_PC,
          "Trap PC preserved with MTVEC collision");

    std::printf("---------------------------------\n");
    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
