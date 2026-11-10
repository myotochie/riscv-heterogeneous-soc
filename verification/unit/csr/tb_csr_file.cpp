#include "Vcsr_file.h"
#include "verilated.h"

#include <cstdint>
#include <cstdlib>
#include <iostream>

static int tests = 0;
static int failures = 0;

static void check(bool condition, const char* name) {
    ++tests;

    if (condition) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++failures;
        std::cerr << "[FAIL] " << name << '\n';
    }
}

static void tick(Vcsr_file& dut) {
    dut.clk = 0;
    dut.eval();

    dut.clk = 1;
    dut.eval();

    dut.clk = 0;
    dut.eval();
}

static uint64_t read_csr(Vcsr_file& dut, uint16_t addr) {
    dut.csr_raddr = addr;
    dut.eval();
    return dut.csr_rdata;
}

static void write_csr(
    Vcsr_file& dut,
    uint16_t addr,
    uint64_t value
) {
    dut.csr_waddr = addr;
    dut.csr_wdata = value;
    dut.csr_we = 1;

    tick(dut);

    dut.csr_we = 0;
    dut.eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vcsr_file dut{};

    constexpr uint16_t MSTATUS = 0x300;
    constexpr uint16_t MTVEC   = 0x305;
    constexpr uint16_t MEPC    = 0x341;
    constexpr uint16_t MCAUSE  = 0x342;
    constexpr uint16_t MTVAL   = 0x343;

    // Initialize every input.
    dut.clk = 0;
    dut.reset = 1;
    dut.trap_valid = 0;
    dut.trap_epc = 0;
    dut.trap_cause = 0;
    dut.trap_tval = 0;
    dut.csr_we = 0;
    dut.csr_raddr = 0;
    dut.csr_waddr = 0;
    dut.csr_wdata = 0;
    dut.mret_valid = 0;

    tick(dut);

    dut.reset = 0;
    dut.eval();

    // T1-T2: Reset.
    check(
        read_csr(dut, MTVEC) == UINT64_C(0x80000100),
        "T1: mtvec reset value"
    );

    check(
        read_csr(dut, MSTATUS) == UINT64_C(0x1800),
        "T2: mstatus reset value"
    );

    // T3: Trap capture.
    dut.trap_epc = UINT64_C(0x80000014);
    dut.trap_cause = 5;
    dut.trap_tval = UINT64_C(0x1000);
    dut.trap_valid = 1;

    tick(dut);

    dut.trap_valid = 0;
    dut.eval();

    check(
        read_csr(dut, MEPC) == UINT64_C(0x80000014) &&
        read_csr(dut, MCAUSE) == 5 &&
        read_csr(dut, MTVAL) == UINT64_C(0x1000),
        "T3: trap context captured"
    );

    // T4: Context persists.
    tick(dut);

    check(
        read_csr(dut, MEPC) == UINT64_C(0x80000014),
        "T4: mepc persists"
    );

    // T5: Write mtvec.
    write_csr(dut, MTVEC, UINT64_C(0x80000200));

    check(
        read_csr(dut, MTVEC) == UINT64_C(0x80000200),
        "T5: mtvec software write"
    );

    // T6: mtvec alignment.
    write_csr(dut, MTVEC, UINT64_C(0x80000303));

    check(
        read_csr(dut, MTVEC) == UINT64_C(0x80000300),
        "T6: mtvec direct-mode alignment"
    );

    // T7: mepc alignment.
    write_csr(dut, MEPC, UINT64_C(0x80000017));

    check(
        read_csr(dut, MEPC) == UINT64_C(0x80000014),
        "T7: mepc alignment"
    );

    // T8: Trap has priority over CSR write.
    dut.csr_waddr = MCAUSE;
    dut.csr_wdata = 99;
    dut.csr_we = 1;

    dut.trap_epc = UINT64_C(0x80000020);
    dut.trap_cause = 7;
    dut.trap_tval = UINT64_C(0x1008);
    dut.trap_valid = 1;

    tick(dut);

    dut.csr_we = 0;
    dut.trap_valid = 0;
    dut.eval();

    check(
        read_csr(dut, MCAUSE) == 7 &&
        read_csr(dut, MEPC) == UINT64_C(0x80000020),
        "T8: trap priority over CSR write"
    );

    // T9-T10: Save interrupt state on trap.
    write_csr(dut, MSTATUS, UINT64_C(0x88));

    dut.trap_valid = 1;
    tick(dut);
    dut.trap_valid = 0;
    dut.eval();

    const uint64_t status_after_trap =
        read_csr(dut, MSTATUS);

    check(
        ((status_after_trap >> 3) & 1U) == 0,
        "T9: trap clears MIE"
    );

    check(
        ((status_after_trap >> 7) & 1U) == 1,
        "T10: trap saves MIE into MPIE"
    );

    // T11: MRET restores MIE.
    dut.mret_valid = 1;
    tick(dut);
    dut.mret_valid = 0;
    dut.eval();

    check(
        ((read_csr(dut, MSTATUS) >> 3) & 1U) == 1,
        "T11: MRET restores MIE"
    );

    // T12: Unknown CSR.
    check(
        read_csr(dut, 0x7FF) == 0,
        "T12: unknown CSR reads zero"
    );
    // T13: Reset must override a simultaneous trap.
    dut.reset = 1;
    dut.trap_valid = 1;
    dut.trap_epc = UINT64_C(0x80000080);
    dut.trap_cause = 7;
    dut.trap_tval = UINT64_C(0x2000);

    tick(dut);

    dut.reset = 0;
    dut.trap_valid = 0;
    dut.eval();

    check(
        read_csr(dut, MEPC) == 0 &&
        read_csr(dut, MCAUSE) == 0 &&
        read_csr(dut, MTVAL) == 0 &&
        read_csr(dut, MTVEC) == UINT64_C(0x80000100),
        "T13: reset overrides trap"
    );

    // T14: Trap must override simultaneous MRET.
    dut.trap_valid = 1;
    dut.mret_valid = 1;
    dut.trap_epc = UINT64_C(0x80000040);
    dut.trap_cause = 4;
    dut.trap_tval = UINT64_C(0x41);

    tick(dut);

    dut.trap_valid = 0;
    dut.mret_valid = 0;
    dut.eval();

    check(
        read_csr(dut, MEPC) == UINT64_C(0x80000040) &&
        read_csr(dut, MCAUSE) == 4 &&
        read_csr(dut, MTVAL) == UINT64_C(0x41),
        "T14: trap overrides MRET"
    );

    // T15: MRET must set MPIE to 1.
    dut.mret_valid = 1;
    tick(dut);
    dut.mret_valid = 0;
    dut.eval();

    check(
        ((read_csr(dut, MSTATUS) >> 7) & 1U) == 1,
        "T15: MRET sets MPIE"
    );
    // Distinct simultaneous read/write addresses must not alias.
    const uint64_t old_mtvec = read_csr(dut, MTVEC);
    dut.csr_raddr = MTVEC;
    dut.csr_waddr = MTVAL;
    dut.csr_wdata = 0x1122334455667788ULL;
    dut.csr_we = 1;
    dut.eval();
    check(dut.csr_rdata == old_mtvec, "T16: independent read port before write edge");
    tick(dut);
    dut.csr_we = 0;
    dut.eval();
    check(dut.csr_rdata == old_mtvec, "T17: write does not change unrelated read CSR");
    check(read_csr(dut, MTVAL) == 0x1122334455667788ULL,
          "T18: independent write port updates its own CSR");

    std::cout << "\nTests run: " << tests << '\n';
    std::cout << "Tests failed: " << failures << '\n';

    dut.final();

    return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
