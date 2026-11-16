#include "Vupper_probe.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>

// Independent unsigned reference, including signed order and arithmetic shift.
static uint64_t reference(unsigned f, unsigned raw, uint64_t a) {
    const uint64_t sign=1ULL<<63;
    const uint64_t b=uint64_t(raw)-(raw>=2048 ? 4096 : 0);
    const unsigned n=raw%64;
    switch(f) {
        case 0:return a+b;
        case 1:return a<<n;
        case 2:return (a^sign)<(b^sign);
        case 3:return a<b;
        case 4:return a^b;
        case 5:return (a>>n) | ((raw/64==16 && (a&sign) && n) ? (~0ULL<<(64-n)) : 0);
        case 6:return a|b;
        case 7:return a&b;
    }
    throw std::runtime_error("invalid reference operation");
}
int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv);Vupper_probe d;
    uint64_t checks=0;unsigned rejected=0;
    auto check=[&](bool ok,const char* msg){++checks;if(!ok)throw std::runtime_error(std::string(msg)+" instr="+std::to_string(d.instr));};
    d.pc=0x80000000;d.valid=1;d.force_illegal=0;
    d.rs2_value=0xfedcba9876543210ULL;
    const uint64_t values[]={0,1,63,64,0x7fffffffffffffffULL,0x8000000000000000ULL,
                             0xffffffffffffffffULL,0xffffffff80000000ULL,0x123456789abcdef0ULL};
    // Every 12-bit immediate and funct3, including all reserved shift prefixes.
    for(unsigned raw=0;raw<4096;++raw) for(unsigned f=0;f<8;++f) {
        bool legal=f!=1&&f!=5 ? true : f==1 ? raw/64==0 : (raw/64==0 || raw/64==16);
        unsigned rs1=(raw+7)%32,rd=(raw+f)%32;
        d.instr=(raw<<20)|(rs1<<15)|(f<<12)|(rd<<7)|0x13;
        d.load_rd=raw%32;d.eval();
        check(d.legal==legal,"legality");
        check(d.uses1==legal && !d.uses2 && d.write_enable==legal && !d.memory_read && !d.memory_write,"controls");
        check(!d.hazard,"immediate bits cannot create rs2 load-use hazard");
        if(!legal){++rejected;continue;}
        check(d.rd==rd,"rd");
        check(d.immediate==uint64_t(raw)-(raw>=2048?4096:0),"sign extension");
        d.load_rd=rs1;d.eval();check(bool(d.hazard)==(rs1!=0),"real rs1 load-use hazard");
        for(uint64_t a:values) for(unsigned sel=0;sel<3;++sel) {
            d.rs1_value=a;d.ex_data=a^0x123456789abcdef0ULL;d.wb_data=~a;
            d.forward_a=sel;d.forward_b=(sel+1)%3;d.eval();
            uint64_t operand=sel==0 ? a : sel==1 ? d.wb_data : d.ex_data;
            check(d.result==reference(f,raw,operand),"ALU/forwarding/immediate selection");
        }
        d.valid=0;d.eval();check(!d.write_enable&&!d.hazard,"invalid slot");d.valid=1;
        d.force_illegal=1;d.eval();check(!d.write_enable,"forced illegal");d.force_illegal=0;
    }
    // All destination/source indices with high shifts (the rs2 field aliases shamt).
    for(unsigned rd=0;rd<32;++rd)for(unsigned rs=0;rs<32;++rs)
      for(unsigned raw:{0u,31u,32u,63u,1024u,1055u,1056u,1087u}) {
        unsigned f=raw>=1024?5:1;
        d.instr=(raw<<20)|(rs<<15)|(f<<12)|(rd<<7)|0x13;d.eval();
        check(d.legal&&d.rd==rd&&d.uses1&&!d.uses2,"register fields and shamt[5]");
    }
    std::cout<<"PASS OP-IMM unit: "<<checks<<" checks, "<<rejected<<" reserved encodings rejected\n";
}
