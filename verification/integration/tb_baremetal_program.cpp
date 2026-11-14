#include "Vrv64_pipeline.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <utility>
#include <vector>
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline d;
    auto tick=[&]() { d.clk=0; d.eval(); d.clk=1; d.eval(); d.clk=0; d.eval(); };
    d.reset=1; d.stall=0; d.flush=0; tick(); tick(); d.reset=0;
    const std::vector<std::pair<unsigned,uint64_t>> expected={
        {2,64},{5,40},{1,0x8000000cULL},{5,42},{10,42}};
    std::vector<std::pair<unsigned,uint64_t>> writes;
    unsigned done_slots=0;
    for (unsigned cycle=0;cycle<100;++cycle) {
        tick();
        if (d.trap_valid_o) throw std::runtime_error("unexpected bare-metal trap");
        if (d.wb_we) {
            if (d.wb_rd==0) throw std::runtime_error("architectural x0 write");
            writes.emplace_back(d.wb_rd,d.wb_data);
        }
        // MEM/WB slot observation, not a general architectural retirement trace.
        if (d.mem_wb_valid && d.mem_wb_pc==0x80000014ULL && d.mem_wb_instr==0x0000006f)
            ++done_slots;
    }
    if (writes!=expected) throw std::runtime_error("bare-metal GPR write sequence mismatch");
    if (done_slots<3) throw std::runtime_error("terminal loop was not stable before timeout");
    std::cout << "PASS assembled ELF: five expected GPR writes, SD/LD signature 42, "
              << done_slots << " terminal-loop slots, no trap in 100 cycles\n";
}
