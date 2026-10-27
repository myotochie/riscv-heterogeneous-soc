#include "Vdata_memory.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdata_memory dut;

    dut.clk = 0;
    dut.reset = 0;
    dut.mem_read = 0;
    dut.mem_write = 0;
    dut.address = 0;
    dut.write_data = 0;
    dut.eval();

    int failed = 0;

    auto check = [&](const char* name,
                     uint64_t address,
                     bool read,
                     bool write,
                     bool misaligned,
                     bool out_of_range) {
        dut.address = address;
        dut.mem_read = read;
        dut.mem_write = write;
        dut.eval();

        bool ok =
            dut.misaligned_fault == misaligned &&
            dut.out_of_range_fault == out_of_range &&
            dut.access_fault == (misaligned || out_of_range);

        std::cout << (ok ? "[PASS] " : "[FAIL] ")
                  << name << '\n';

        if (!ok) ++failed;
    };

    check("Aligned LD",          0x40,   true,  false, false, false);
    check("Misaligned LD",       0x41,   true,  false, true,  false);
    check("Out-of-range LD",     0x1000, true,  false, false, true);
    check("Misaligned SD",       0x41,   false, true,  true,  false);
    check("Inactive memory",     0x41,   false, false, false, false);

    std::cout << "Tests run: 5\n";
    std::cout << "Tests failed: " << failed << '\n';

    dut.final();
    return failed ? 1 : 0;
}
