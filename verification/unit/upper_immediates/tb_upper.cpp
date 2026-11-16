#include "Vupper_probe.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vupper_probe d;
    unsigned checks=0;
    auto check=[&](bool ok) { ++checks; if (!ok) throw std::runtime_error("U-type unit mismatch at instruction="+std::to_string(d.instr)); };
    d.valid=1; d.force_illegal=0; d.rs1_value=0xdeadbeef11223344ULL;
    d.rs2_value=0xbad; d.ex_data=0xaabbccdd12345678ULL; d.wb_data=0x88776655fedcba98ULL;
    d.pc=0x1234567880000004ULL; d.forward_a=2; d.forward_b=1;
    // Exhaust every U payload: no immediate bits may become register sources
    // or funct3/funct7 restrictions. Expected immediate uses numeric subtraction.
    for (unsigned u=0;u<(1u<<20);++u) for (unsigned op : {0x37u,0x17u}) {
        d.instr=(u<<12)|((u&31)<<7)|op; d.load_rd=(u>>3)&31; d.eval();
        uint64_t imm=(uint64_t(u)<<12) - (u&0x80000 ? (1ULL<<32) : 0);
        check(d.legal && !d.uses1 && !d.uses2 && !d.hazard && d.rd==(u&31));
        check(d.immediate==imm && d.result==imm+(op==0x17 ? d.pc : 0));
        check(d.write_enable && !d.memory_read && !d.memory_write);
    }
    for (uint64_t pc : {0ULL,0x80000004ULL,0x1234567880000004ULL,0xfffffffffffffffcuLL})
      for (unsigned u : {0u,1u,0x7ffffu,0x80000u,0xfffffu})
       for (unsigned rd=0;rd<32;++rd) for (unsigned op : {0x37u,0x17u})
        for (unsigned a=0;a<3;++a) for (unsigned b=0;b<3;++b) {
            d.instr=(u<<12)|(rd<<7)|op;d.pc=pc;d.forward_a=a;d.forward_b=b;
            d.valid=1;d.force_illegal=0;d.eval();
            uint64_t imm=(uint64_t(u)<<12)-(u&0x80000 ? (1ULL<<32):0);
            check(d.result==imm+(op==0x17 ? pc:0));
            check(d.forwarded_rs1==(a==0?d.rs1_value:a==1?d.wb_data:d.ex_data));
            d.valid=0;d.eval();check(!d.write_enable);
            d.valid=1;d.force_illegal=1;d.eval();check(!d.write_enable);
        }
    std::cout<<"PASS U-type unit: "<<checks<<" checks (all 20-bit payloads, 64-bit PCs, bypasses, invalid/illegal)\n";
}
