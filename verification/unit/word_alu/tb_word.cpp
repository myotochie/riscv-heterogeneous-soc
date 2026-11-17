#include "Vupper_probe.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>

static uint64_t sext(uint32_t v) { return (v & 0x80000000u) ? (0xffffffff00000000ULL | v) : v; }
static uint32_t ref(unsigned f, unsigned f7, uint32_t a, uint32_t b) {
    unsigned n=b&31;
    if(f==0) return f7==32 ? a-b : a+b;
    if(f==1) return a<<n;
    if(f7==0) return a>>n;
    return (a>>n) | ((a&0x80000000u) && n ? (~uint32_t(0) << (32-n)) : 0);
}
int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv); Vupper_probe d;
    d.pc=0x80000000; d.valid=1; d.force_illegal=0; d.forward_a=0; d.forward_b=0;
    const uint64_t values[]={0,1,31,32,63,0x7fffffffULL,0x80000000ULL,0xffffffffULL,0x1234567880000000ULL,~0ULL};
    uint64_t count=0; auto check=[&](bool ok,const char* s){++count;if(!ok){std::cerr<<s<<" instruction=0x"<<std::hex<<d.instr<<"\n";throw std::runtime_error(s);}};
    for(unsigned op:{0x1bu,0x3bu}) for(unsigned f=0;f<8;++f) for(unsigned f7=0;f7<128;++f7) for(unsigned field=0;field<32;++field) {
        const bool legal=op==0x1b ? (f==0 || (f==1&&f7==0) || (f==5&&(f7==0||f7==32))) :
                         ((f==0&&(f7==0||f7==32)) || (f==1&&f7==0) || (f==5&&(f7==0||f7==32)));
        d.instr=(f7<<25)|(field<<20)|(3u<<15)|(f<<12)|(5u<<7)|op;
        d.load_rd=field;d.eval();
        check(bool(d.legal)==legal,"decode legality");
        check(bool(d.write_enable)==legal && !d.memory_read && !d.memory_write,"safe controls");
        check(bool(d.uses1)==legal && bool(d.uses2)==(legal&&op==0x3b),"source use");
        check(bool(d.hazard)==(legal && (field==3 || (op==0x3b&&field!=0))),"source hazard");
        if(!legal)continue;
        for(uint64_t a:values) for(uint64_t b:values) {
            d.rs1_value=a;d.rs2_value=b;d.eval();
            const uint32_t operand=op==0x1b ? uint32_t(d.immediate) : uint32_t(b);
            check(d.result==sext(ref(f,op==0x1b&&f==0 ? 0 : f7,uint32_t(a),operand)),"word result");
        }
        d.load_rd=3;d.eval();check(d.hazard,"rs1 hazard");
        d.valid=0;d.eval();check(!d.write_enable&&!d.hazard,"invalid slot");d.valid=1;
        d.force_illegal=1;d.eval();check(!d.write_enable,"illegal suppression");d.force_illegal=0;
    }
    // Forwarded source operands must feed both inputs of OP-32.
    d.instr=(4u<<20)|(3u<<15)|(5u<<7)|0x3b;d.rs1_value=0;d.rs2_value=0;
    d.ex_data=0x7fffffff;d.wb_data=1;d.forward_a=2;d.forward_b=1;d.eval();
    check(d.result==0xffffffff80000000ULL,"forwarded addw");
    std::cout<<"PASS word decode/ALU: "<<count<<" checks\n";
}
