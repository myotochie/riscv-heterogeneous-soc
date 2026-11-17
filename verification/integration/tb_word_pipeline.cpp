#include "Vrv64_pipeline.h"
#include "Vrv64_pipeline___024root.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <utility>
#include <vector>
int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv); Vrv64_pipeline d; auto *r=d.rootp;
    auto check=[](bool ok,const char *msg){if(!ok)throw std::runtime_error(msg);};
    auto tick=[&](){d.clk=1;d.eval();d.clk=0;d.eval();};
    d.clk=0;d.reset=1;d.stall=0;d.flush=0;d.eval();tick();tick();d.reset=0;d.eval();
    std::vector<std::pair<unsigned,uint64_t>> writes;
    unsigned hazards=0,ex_bypass=0,wb_bypass=0;
    for(unsigned i=0;i<160;++i){
        d.eval();
        if(r->rv64_pipeline__DOT__u_frontend__DOT__hazard_stall_pc)++hazards;
        if(r->rv64_pipeline__DOT__u_frontend__DOT__id_ex_valid){
            if(r->rv64_pipeline__DOT__u_frontend__DOT__forward_a==2 || r->rv64_pipeline__DOT__u_frontend__DOT__forward_b==2)++ex_bypass;
            if(r->rv64_pipeline__DOT__u_frontend__DOT__forward_a==1 || r->rv64_pipeline__DOT__u_frontend__DOT__forward_b==1)++wb_bypass;
        }
        check(!d.trap_valid_o,"unexpected trap");
        if(d.wb_we){check(d.wb_rd!=0,"x0 write");writes.emplace_back(d.wb_rd,d.wb_data);}
        tick();
    }
    const std::vector<std::pair<unsigned,uint64_t>> expected={
      {1,0xffffffffffffffffULL},{2,0},{3,0xffffffff80000000ULL},{4,1},
      {5,0xffffffffffffffffULL},{6,0xfffffffffffffffeULL},{7,0xffffffff80000000ULL},
      {8,1},{9,0xffffffffffffffffULL},{10,0xffffffffffffffffULL},
      {11,0xffffffff80000000ULL},{12,0xffffffffffffffffULL},{13,0},{14,1}};
    if(writes!=expected){for(auto [rd,v]:writes)std::cerr<<std::hex<<rd<<":"<<v<<" ";std::cerr<<"\n";throw std::runtime_error("write sequence");}
    check(hazards==1 && ex_bypass && wb_bypass,"hazard/forwarding coverage");
    std::cout<<"PASS word pipeline: "<<writes.size()<<" writes, "<<hazards<<" load-use hazard\n";
}
