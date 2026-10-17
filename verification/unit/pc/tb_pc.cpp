
#include "Vpc.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(
    Vpc& dut,
    uint64_t expected,
    const char* name
) {
    ++tests_run;

    const uint64_t actual = dut.pc_value;

    if (actual == expected) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | expected=0x" << std::hex << expected
                  << " actual=0x" << actual
                  << std::dec << '\n';
    }
}

void rising_edge(Vpc& dut) {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vpc dut{};

    dut.clk = 0;
    dut.reset = 1;
    dut.redirect = 0;
    dut.redirect_target = 0;
    rising_edge(dut);

    check(dut, 0x80000000ULL, "Synchronous reset");

    dut.reset = 0;
    rising_edge(dut);
    check(dut, 0x80000004ULL, "Sequential increment +4");

    rising_edge(dut);
    check(dut, 0x80000008ULL, "Second sequential increment");

    dut.redirect = 1;
    dut.redirect_target = 0x80001000ULL;
    rising_edge(dut);
    check(dut, 0x80001000ULL, "Redirect loads target");

    dut.redirect = 0;
    rising_edge(dut);
    check(dut, 0x80001004ULL, "Increment after redirect");

    dut.redirect = 1;
    dut.redirect_target = 0x80002000ULL;
    dut.reset = 1;
    rising_edge(dut);
    check(dut, 0x80000000ULL, "Reset takes priority over redirect");

    dut.reset = 0;
    dut.redirect = 0;
    rising_edge(dut);
    check(dut, 0x80000004ULL, "Increment after reset");

    // Verify that the PC does not change without a rising edge.
    dut.clk = 0;
    dut.eval();
    check(dut, 0x80000004ULL, "PC stable without rising edge");

    std::cout << "\nTests run: " << tests_run
              << "\nTests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
