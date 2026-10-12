
#include "Vregfile.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check_result(
    Vregfile& dut,
    uint64_t expected1,
    uint64_t expected2,
    const char* name
) {
    dut.eval();
    ++tests_run;

    const bool pass =
        (dut.rd1 == expected1) &&
        (dut.rd2 == expected2);

    if (pass) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | rd1=0x" << std::hex << dut.rd1
                  << " expected=0x" << expected1
                  << " | rd2=0x" << dut.rd2
                  << " expected=0x" << expected2
                  << std::dec << '\n';
    }
}

void write_register(
    Vregfile& dut,
    uint8_t address,
    uint64_t value
) {
    // Prepare the write while the clock is low.
    dut.clk = 0;
    dut.we = 1;
    dut.rd = address;
    dut.wd = value;
    dut.eval();

    // The register is written on the rising edge.
    dut.clk = 1;
    dut.eval();

    // Return to the low phase.
    dut.clk = 0;
    dut.eval();

    dut.we = 0;
    dut.eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vregfile dut{};

    // Initial signal values.
    dut.clk = 0;
    dut.we = 0;
    dut.rs1 = 0;
    dut.rs2 = 0;
    dut.rd = 0;
    dut.wd = 0;
    dut.eval();

    // Test 1: x0 must always read as zero.
    dut.rs1 = 0;
    dut.rs2 = 0;
    check_result(dut, 0, 0, "x0 reads zero");

    // Test 2: writing to x0 must be ignored.
    write_register(dut, 0, UINT64_MAX);
    dut.rs1 = 0;
    dut.rs2 = 0;
    check_result(dut, 0, 0, "write to x0 ignored");

    // Test 3: write and read an ordinary register.
    write_register(dut, 1, 42);
    dut.rs1 = 1;
    dut.rs2 = 0;
    check_result(dut, 42, 0, "write and read x1");

    // Test 4: both read ports access different registers.
    write_register(dut, 2, 99);
    dut.rs1 = 1;
    dut.rs2 = 2;
    check_result(dut, 42, 99, "simultaneous dual-port read");

    // Test 5: write enable low must prevent a write.
    dut.clk = 0;
    dut.we = 0;
    dut.rd = 1;
    dut.wd = 1234;
    dut.eval();

    dut.clk = 1;
    dut.eval();

    dut.clk = 0;
    dut.eval();

    dut.rs1 = 1;
    dut.rs2 = 2;
    check_result(dut, 42, 99, "write disabled");

    // Test 6: verify the value changes only after the rising edge.
    dut.clk = 0;
    dut.we = 1;
    dut.rd = 1;
    dut.wd = 777;
    dut.eval();

    dut.rs1 = 1;
    dut.rs2 = 2;
    check_result(dut, 42, 99, "old value before rising edge");

    dut.clk = 1;
    dut.eval();
    check_result(dut, 777, 99, "new value after rising edge");

    dut.clk = 0;
    dut.we = 0;
    dut.eval();

    // Test 7: most significant bit set.
    write_register(dut, 3, UINT64_C(0x8000000000000000));
    dut.rs1 = 3;
    dut.rs2 = 0;
    check_result(
        dut,
        UINT64_C(0x8000000000000000),
        0,
        "most significant bit"
    );

    // Test 8: all 64 bits set.
    write_register(dut, 4, UINT64_MAX);
    dut.rs1 = 4;
    dut.rs2 = 0;
    check_result(dut, UINT64_MAX, 0, "all bits set");

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
