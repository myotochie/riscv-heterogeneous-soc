#include "Vdata_memory.h"
#include "verilated.h"

#include <cstdint>
#include <cstdlib>
#include <iostream>

static int checks = 0;
static int failures = 0;

static void check(bool condition, const char* message) {
    ++checks;
    if (condition) {
        std::cout << "[PASS] " << message << '\n';
    } else {
        ++failures;
        std::cerr << "[FAIL] " << message << '\n';
    }
}

static void tick(Vdata_memory& dut) {
    dut.clk = 0;
    dut.eval();

    dut.clk = 1;
    dut.eval();

    dut.clk = 0;
    dut.eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdata_memory dut{};

    constexpr uint64_t VALUE_A = UINT64_C(0x1122334455667788);
    constexpr uint64_t VALUE_B = UINT64_C(0xAABBCCDDEEFF0011);

    dut.clk = 0;
    dut.reset = 1;
    dut.mem_read = 0;
    dut.mem_write = 0;
    dut.address = 64;
    dut.write_data = 0;
    tick(dut);

    // 1. Disabled read returns zero.
    dut.reset = 0;
    dut.eval();
    check(dut.read_data == 0 && dut.access_fault == 0,
          "Disabled read returns zero");

    // 2. Write a 64-bit value at address 64.
    dut.mem_write = 1;
    dut.write_data = VALUE_A;
    tick(dut);

    dut.mem_write = 0;
    dut.mem_read = 1;
    dut.eval();

    check(dut.read_data == VALUE_A,
          "64-bit write followed by read");

    // 3. Verify the expected little-endian word.
    check(dut.read_data == UINT64_C(0x1122334455667788),
          "Little-endian 64-bit reconstruction");

    // 4. Unaligned access.
    dut.address = 65;
    dut.eval();

    check(dut.access_fault == 1 && dut.read_data == 0,
          "Unaligned LD is rejected");

    // 5. Out-of-range access.
    dut.address = 4096;
    dut.eval();

    check(dut.access_fault == 1 && dut.read_data == 0,
          "Out-of-range LD is rejected");

    // 6. High address must not alias a valid address.
    dut.address = UINT64_C(0x0000000100000040);
    dut.eval();

    check(dut.access_fault == 1 && dut.read_data == 0,
          "High address cannot alias low memory");

    // 7. Reset blocks writes.
    dut.mem_read = 0;
    dut.mem_write = 1;
    dut.reset = 1;
    dut.address = 64;
    dut.write_data = VALUE_B;
    tick(dut);

    dut.reset = 0;
    dut.mem_write = 0;
    dut.mem_read = 1;
    dut.eval();

    check(dut.read_data == VALUE_A,
          "Reset blocks memory writes");

    // 8. A second aligned location can store data.
    dut.mem_read = 0;
    dut.mem_write = 1;
    dut.address = 72;
    dut.write_data = VALUE_B;
    tick(dut);

    dut.mem_write = 0;
    dut.mem_read = 1;
    dut.eval();

    check(dut.read_data == VALUE_B,
          "Second aligned memory location works");

    std::cout << "\nTests run: " << checks
              << "\nTests failed: " << failures << '\n';

    dut.final();
    return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
