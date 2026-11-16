#include "Vrv64_datapath.h"
#include "verilated.h"
#include <iostream>
#include <stdexcept>
int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv);Vrv64_datapath d;
    auto edge=[&](){d.clk=1;d.eval();d.clk=0;d.eval();};
    d.clk=0;
    // Initialize x5=17, then try every new family with rd=x5.
    d.instr=0x01100293;d.eval();edge();
    for(unsigned word:{0x00102293u,0x00103293u,0x00104293u,0x00106293u,
                       0x00107293u,0x00101293u,0x00105293u,0x40105293u}) {
        d.instr=word;d.eval();if(!d.illegal_instr)throw std::runtime_error("teaching contract expanded");edge();
        d.instr=0x00028313;d.eval(); // ADDI x6,x5,0: x5 must remain 17.
        if(d.result!=17)throw std::runtime_error("rejected OP-IMM modified teaching GPR");
    }
    std::cout<<"PASS teaching R/ADDI contract: eight new OP-IMM families rejected without GPR write\n";
}
