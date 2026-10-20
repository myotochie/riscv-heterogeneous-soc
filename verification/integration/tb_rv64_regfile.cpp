#include "Vrv64_pipeline.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(bool condition, const char* name) {
    ++tests_run;

    if (condition)
        std::cout << "[PASS] " << name << '\n';
    else {
        ++tests_failed;
        std::cout << "[FAIL] " << name << '\n';
    }
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

    // Four cycles to reach MEM/WB, then three
    // additional cycles to commit x1, x2 and x3.
    for (int cycle = 0; cycle < 7; ++cycle)
        tick(dut);


    check(
        dut.rv64_pipeline__DOT__u_frontend__DOT__u_fetch_decode__DOT__u_decode__DOT__u_regfile__DOT__debug_x1 == 5,
        "register x1 contains 5"
    );

    check(
        dut.rv64_pipeline__DOT__u_frontend__DOT__u_fetch_decode__DOT__u_decode__DOT__u_regfile__DOT__debug_x2 == 7,
        "register x2 contains 7"
    );

    check(
        dut.rv64_pipeline__DOT__u_frontend__DOT__u_fetch_decode__DOT__u_decode__DOT__u_regfile__DOT__debug_x3 == 9,
        "register x3 contains 9"
    );

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
