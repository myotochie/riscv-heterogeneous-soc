#include "Vrv64_pipeline.h"
#include "Vrv64_pipeline___024root.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>
int main(int argc,char **argv){
 Verilated::commandArgs(argc,argv);if(argc!=2)return 2;std::ifstream in(argv[1]);
 uint64_t trap,cause,epc,tval,hazards;in>>std::hex>>trap>>cause>>epc>>tval>>hazards;
 std::vector<std::pair<unsigned,uint64_t>> expected,writes;unsigned rd;uint64_t value;while(in>>std::hex>>rd>>value)expected.emplace_back(rd,value);
 Vrv64_pipeline d;auto*r=d.rootp;auto check=[](bool b,const char*s){if(!b)throw std::runtime_error(s);};
 auto tick=[&](){d.clk=1;d.eval();d.clk=0;d.eval();};
 d.clk=0;d.reset=1;d.stall=0;d.flush=0;d.eval();tick();tick();d.reset=0;
 unsigned seen=0,stalls=0;
 for(unsigned i=0;i<130;++i){d.eval();
  if(r->rv64_pipeline__DOT__u_frontend__DOT__hazard_stall_pc)++stalls;
  if(d.wb_we){check(d.wb_rd!=0,"x0 write");writes.emplace_back(d.wb_rd,d.wb_data);}
  if(d.trap_valid_o){++seen;check(d.trap_cause_o==cause&&d.trap_epc_o==epc&&d.trap_tval_o==tval,"trap metadata");}
  tick();
 }
 if(writes!=expected){for(auto [reg,v]:writes)std::cerr<<std::hex<<reg<<":"<<v<<" ";std::cerr<<"\n";throw std::runtime_error("write sequence");}
 check(seen==trap,"trap count");check(stalls==hazards,"load-use stall count");
 std::cout<<"PASS word-memory pipeline: writes="<<writes.size()<<" traps="<<seen<<" stalls="<<stalls<<"\n";
}
