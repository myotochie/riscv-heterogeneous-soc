#include "Vfetch_path.h"
#include "verilated.h"
#include <iostream>
#include <stdexcept>
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vfetch_path d;
    auto tick = [&]() { d.clk=0; d.eval(); d.clk=1; d.eval(); d.clk=0; d.eval(); };
    auto require = [](bool ok) { if (!ok) throw std::runtime_error("external fetch mismatch"); };
    d.reset=1; d.stall_pc=0; d.stall_if_id=0; d.flush=0;
    d.trap_redirect=0; d.trap_target=0;
    tick(); require(d.pc_value==0x80000000ULL && !d.if_id_valid);
    d.reset=0; tick(); require(d.if_id_pc==0x80000000ULL && d.if_id_instr==0x00500093 && d.if_id_valid);
    d.stall_pc=1; d.stall_if_id=1; tick(); require(d.if_id_instr==0x00500093 && d.pc_value==0x80000004ULL);
    d.stall_pc=0; d.stall_if_id=0; tick(); require(d.if_id_instr==0x00700113);
    d.trap_redirect=1; d.trap_target=0; d.flush=1; tick(); require(!d.if_id_valid && d.pc_value==0);
    if (argc>1) { d.flush=0; d.trap_redirect=0; tick(); return 2; }
    // An invalid old PC is discarded by another redirect, not accepted into IF/ID.
    d.trap_target=0x80000008ULL; tick(); require(!d.if_id_valid);
    d.flush=0; d.trap_redirect=0; tick(); require(d.if_id_instr==0x00900193 && d.if_id_pc==0x80000008ULL);
    tick(); require(d.if_id_instr==0x0000006f);
    // PC is now outside this four-word ROM; a held IF/ID must not diagnose it.
    d.stall_pc=1; d.stall_if_id=1; tick(); require(d.if_id_instr==0x0000006f);
    d.reset=1; tick(); require(!d.if_id_valid && d.pc_value==0x80000000ULL);
    std::cout << "PASS external fetch: reset, capture, stall, flush, redirect\n";
}
