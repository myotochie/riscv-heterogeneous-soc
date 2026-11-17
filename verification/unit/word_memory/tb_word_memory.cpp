#include "Vdata_memory.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
int main(int argc,char**argv) {
 Verilated::commandArgs(argc,argv); Vdata_memory d; unsigned checks=0;
 auto check=[&](bool ok,const char *msg){++checks;if(!ok)throw std::runtime_error(msg);};
 auto tick=[&](){d.clk=0;d.eval();d.clk=1;d.eval();d.clk=0;d.eval();};
 d.clk=0;d.reset=0;d.mem_read=0;d.mem_write=1;d.word_access=0;d.address=0;d.write_data=0x1122334455667788ULL;tick();
 d.word_access=1;d.address=4;d.write_data=0x80000000;tick();
 d.mem_write=0;d.mem_read=1;d.word_access=0;d.address=0;d.eval();check(d.read_data==0x8000000055667788ULL,"SW preserves neighboring bytes");
 d.word_access=1;d.address=4;d.eval();check(d.read_data==0xffffffff80000000ULL&&!d.access_fault,"LW sign extension at upper half");
 d.address=0;d.eval();check(d.read_data==0x55667788ULL,"LW positive value");
 d.mem_read=0;d.mem_write=1;d.address=4092;d.write_data=0xffffffff;d.eval();check(!d.access_fault,"last word valid");tick();
 d.mem_write=0;d.mem_read=1;d.eval();check(d.read_data==~0ULL,"last word read");
 for(unsigned addr:{1u,2u,3u,4093u,4095u}) {d.address=addr;d.eval();check(d.access_fault&&d.misaligned_fault&&!d.out_of_range_fault,"misalignment priority");}
 for(uint64_t addr:{4096ULL,0xfffffffffffffff8ULL}) {d.address=addr;d.eval();check(d.access_fault&&!d.misaligned_fault&&d.out_of_range_fault,"out of range");}
 d.mem_read=0;d.mem_write=1;d.address=4093;d.write_data=0;tick();d.mem_write=0;d.mem_read=1;d.address=4092;d.eval();check(d.read_data==~0ULL,"faulting store does not write");
 d.mem_read=0;d.mem_write=1;d.reset=1;d.address=4;d.write_data=0;tick();d.reset=0;d.mem_write=0;d.mem_read=1;d.eval();check(d.read_data==0xffffffff80000000ULL,"reset suppresses store");
 d.word_access=0;d.address=4;d.eval();check(d.access_fault&&d.misaligned_fault,"doubleword still needs eight-byte alignment");
 d.address=4088;d.eval();check(!d.access_fault,"last doubleword remains valid");
 std::cout<<"PASS word memory: "<<checks<<" checks\n";
}
