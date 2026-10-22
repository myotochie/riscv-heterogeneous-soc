#include "Vforwarding_mux.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(bool condition, const char* name) {
    ++tests_run;

    if (condition) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name << '\n';
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vforwarding_mux dut{};

    dut.original_data = 0x1111111111111111ULL;
    dut.ex_mem_data   = 0x2222222222222222ULL;
    dut.mem_wb_data   = 0x3333333333333333ULL;

    // No forwarding
    dut.forward_sel = 0;
    dut.eval();

    check(
        dut.forwarded_data == 0x1111111111111111ULL,
        "00: select original ID/EX data"
    );

    // Forwarding from MEM/WB
    dut.forward_sel = 1;
    dut.eval();

    check(
        dut.forwarded_data == 0x3333333333333333ULL,
        "01: select MEM/WB data"
    );

    // Forwarding from EX/MEM
    dut.forward_sel = 2;
    dut.eval();

    check(
        dut.forwarded_data == 0x2222222222222222ULL,
        "10: select EX/MEM data"
    );

    // Reserved selection
    dut.forward_sel = 3;
    dut.eval();

    check(
        dut.forwarded_data == 0x1111111111111111ULL,
        "11: default to original data"
    );

    // Verify full 64-bit data propagation
    dut.ex_mem_data = 0xFEDCBA9876543210ULL;
    dut.forward_sel = 2;
    dut.eval();

    check(
        dut.forwarded_data == 0xFEDCBA9876543210ULL,
        "64-bit forwarding preserves all bits"
    );

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
