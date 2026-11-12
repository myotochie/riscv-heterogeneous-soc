#include "Vrv64_pipeline.h"
#include "verilated.h"
#include <iostream>
#include <stdexcept>
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vrv64_pipeline d;
    auto tick = [&]() { d.clk=0; d.eval(); d.clk=1; d.eval(); d.clk=0; d.eval(); };
    d.reset=1; d.stall=0; d.flush=0; tick(); tick(); d.reset=0;
    bool link=false, result=false;
    for (int cycle=0; cycle<100; ++cycle) {
        tick();
        if (d.trap_valid_o) throw std::runtime_error("unexpected trap");
        if (d.wb_we && d.wb_rd==1) {
            if (d.wb_data!=0x8000000cULL) throw std::runtime_error("incorrect link");
            link=true;
        }
        if (d.wb_we && d.wb_rd==10) {
            if (d.wb_data!=42) throw std::runtime_error("incorrect store/load result");
            result=true;
        }
    }
    if (!link || !result) throw std::runtime_error("external program timed out");
    std::cout << "PASS external program: JAL/JALR, signature SD/LD = 42, 100 cycles\n";
}
