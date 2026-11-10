#include "Vdecoder.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdecoder d;
    int failed = 0, checks = 0;
    auto test = [&](uint32_t instr, bool legal, bool uses1) {
        d.instr = instr; d.eval(); ++checks;
        bool ok = d.illegal_instr == !legal && d.reg_write == legal &&
            d.uses_rs1 == uses1 && !d.uses_rs2 && !d.mem_read && !d.mem_write &&
            !d.csr_valid && !d.mret_valid && d.rd == ((instr >> 7) & 31);
        if (!ok) { ++failed; std::cerr << "[FAIL] decode 0x" << std::hex << instr << '\n'; }
    };
    // JAL's immediate aliases both register fields: neither is a dependency.
    for (unsigned rd = 0; rd < 32; ++rd)
        for (unsigned rs = 0; rs < 32; ++rs) {
            test(0x8000006fu | (rd << 7) | (rs << 15) | (rs << 20), true, false);
            for (unsigned f = 0; f < 8; ++f)
                test(0xfff00067u | (rd << 7) | (rs << 15) | (f << 12), f == 0, f == 0);
        }
    std::cout << "Tests run: " << checks << "\nTests failed: " << failed << '\n';
    return failed ? 1 : 0;
}
