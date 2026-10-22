#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(bool condition, const char* name) {
    ++tests_run;
    std::cout << (condition ? "[PASS] " : "[FAIL] ")
              << name << '\n';
    if (!condition) ++tests_failed;
}

void tick(Vrv64_pipeline& dut) {
    dut.clk = 0;
    dut.eval();

    dut.clk = 1;
    dut.eval();

    dut.clk = 0;
    dut.eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline dut{};

    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;

    tick(dut);

    dut.reset = 0;

    // Laisser les trois instructions traverser le pipeline.
    for (int cycle = 0; cycle < 10; ++cycle) {
        tick(dut);
    }

    const uint64_t x1 =
        dut.rv64_pipeline__DOT__u_frontend__DOT__u_fetch_decode__DOT__u_decode__DOT__u_regfile__DOT__debug_x1;

    const uint64_t x2 =
        dut.rv64_pipeline__DOT__u_frontend__DOT__u_fetch_decode__DOT__u_decode__DOT__u_regfile__DOT__debug_x2;

    const uint64_t x3 =
        dut.rv64_pipeline__DOT__u_frontend__DOT__u_fetch_decode__DOT__u_decode__DOT__u_regfile__DOT__debug_x3;

    std::cout << "\n--- RAW DEBUG ---\n";
    std::cout << "x1 = " << x1 << " (expected 5)\n";
    std::cout << "x2 = " << x2 << " (expected 12)\n";
    std::cout << "x3 = " << x3 << " (expected 17)\n";
    std::cout << "-----------------\n";

    check(x1 == 5,  "RAW program: x1 = 5");
    check(x2 == 12, "RAW program: x2 = 12");
    check(x3 == 17, "RAW program: x3 = 17");

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
