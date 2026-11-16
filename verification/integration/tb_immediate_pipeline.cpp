#include "Vrv64_pipeline.h"
#include "Vrv64_pipeline___024root.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include <utility>
int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv);
    if(argc!=4) return 2;
    std::ifstream input(argv[1]);
    uint64_t want_traps,cause,epc,tval,want_hazards,want_mrets;
    if(!(input>>std::hex>>want_traps>>cause>>epc>>tval>>want_hazards>>want_mrets)) return 2;
    std::vector<std::pair<unsigned,uint64_t>> expected,writes;
    unsigned rd;uint64_t value;
    while(input>>std::hex>>rd>>value) expected.emplace_back(rd,value);
    const std::string scenario=argv[2],mode=argv[3];
    auto check=[](bool ok,const char* msg){if(!ok)throw std::runtime_error(msg);};
    Vrv64_pipeline d;auto*r=d.rootp;
    auto tick=[&](){d.clk=1;d.eval();d.clk=0;d.eval();};
    d.clk=0;d.reset=1;d.stall=0;d.flush=0;d.eval();tick();tick();d.reset=0;d.eval();
    unsigned traps=0,hazards=0,mrets=0,held=0,cancel_window=0;
    unsigned ex_bypass=0,wb_bypass=0,trap_collision=0,mret_collision=0,alias_seen=0,reserved=0;
    bool injected=false;
    for(unsigned cycle=0;cycle<160;++cycle) {
        const bool ex_valid=r->rv64_pipeline__DOT__u_frontend__DOT__id_ex_valid;
        const uint32_t instr=r->rv64_pipeline__DOT__u_frontend__DOT__id_ex_instr;
        const bool immediate=(instr&127)==0x13 && ((instr>>12)&7)!=0;
        if(mode!="normal" && !injected && ex_valid && immediate) {
            injected=true;
            if(mode=="flush")d.flush=1;
            if(mode=="reset")d.reset=1;
        }
        if(mode=="stall" && injected && held<3){d.stall=1;++held;}else d.stall=0;
        d.eval();
        if(d.stall || d.flush || d.reset) check(!d.wb_we && !d.trap_valid_o,"control must suppress WB/trap");
        if(r->rv64_pipeline__DOT__u_frontend__DOT__hazard_stall_pc && !d.stall) ++hazards;
        // XORI immediate aliases rs2=13 after LD x13, but its real source is x9.
        if(r->rv64_pipeline__DOT__u_frontend__DOT__if_id_instr==0x00d4c413 &&
           r->rv64_pipeline__DOT__u_frontend__DOT__if_id_valid) {
            ++alias_seen;check(!r->rv64_pipeline__DOT__u_frontend__DOT__hazard_stall_pc,"false immediate rs2 load-use dependency");
        }
        if(ex_valid && immediate && !d.stall && !d.reset && !d.flush &&
           r->rv64_pipeline__DOT__u_frontend__DOT__id_ex_illegal_instr)++reserved;
        if(ex_valid && !d.stall && !d.reset && !d.flush) {
            if(r->rv64_pipeline__DOT__u_frontend__DOT__forward_a==2)++ex_bypass;
            if(r->rv64_pipeline__DOT__u_frontend__DOT__forward_a==1 ||
               r->rv64_pipeline__DOT__u_frontend__DOT__forward_b==1)++wb_bypass;
        }
        if(d.wb_we) {
            check(d.wb_rd!=0,"architectural x0 write");
            writes.emplace_back(d.wb_rd,d.wb_data);
        }
        if(d.trap_valid_o) {
            ++traps;
            check(d.trap_cause_o==cause && d.trap_epc_o==epc && d.trap_tval_o==tval,"precise trap metadata");
            if(ex_valid && immediate)++trap_collision;
        }
        if(r->rv64_pipeline__DOT__mret_retire){++mrets;if(ex_valid&&immediate)++mret_collision;}
        uint64_t before=d.pc_value;tick();
        if(d.stall)check(d.pc_value==before,"stall must hold PC");
        if(d.reset || d.flush){d.reset=0;d.flush=0;d.eval();cancel_window=1;}
        else if(cancel_window && ++cancel_window==4)break;
    }
    if(mode=="flush"||mode=="reset")expected.clear();
    if(writes!=expected){
        for(auto w:writes)std::cerr<<std::hex<<w.first<<":"<<w.second<<" ";
        throw std::runtime_error("architectural write sequence mismatch");
    }
    check(traps==want_traps && hazards==want_hazards && mrets==want_mrets,"trap/hazard/MRET counts mismatch");
    if(mode!="normal")check(injected,"control stimulus not reached");
    if(mode=="stall")check(held==3,"stall duration not exercised");
    if(scenario=="data")check(ex_bypass && wb_bypass && alias_seen,"bypass/false-hazard coverage not reached");
    if(scenario=="reserved")check(reserved==4,"reserved shift coverage missing");
    if(scenario=="trap")check(trap_collision==1,"MEM trap / EX OP-IMM collision missing");
    if(scenario=="mret")check(mret_collision==1,"retiring MRET / EX OP-IMM collision missing");
    std::cout<<"PASS OP-IMM pipeline "<<scenario<<" "<<mode<<": writes="<<writes.size()<<" traps="<<traps<<" hazards="<<hazards<<"\n";
}
