#include "Vinstruction_memory.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vinstruction_memory dut;
    const bool partial = argc > 1;
    int checks = 0;
    auto check = [&](uint64_t address, uint32_t word, bool fault) {
        dut.address = address; dut.eval(); ++checks;
        if (dut.instruction != word || bool(dut.address_fault) != fault)
            throw std::runtime_error("instruction/address classification mismatch");
    };
    constexpr uint64_t base = 0x80000000ULL;
    check(base, 0x00500093, false);
    check(base+4, 0x00700113, false);
    check(base+8, partial ? 0x00000013 : 0x00900193, false);
    check(base+12, partial ? 0x00000013 : 0x0000006f, false);
    for (auto address : {base-4, base+16, base+1, base+2, base+3,
                         uint64_t{0}, UINT64_MAX, base+(uint64_t{1}<<32)})
        check(address, 0x00000013, true);
    std::cout << "PASS instruction memory: " << checks << " checks\n";
}
