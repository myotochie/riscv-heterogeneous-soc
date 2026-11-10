#include "Vexecute_stage.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vexecute_stage d;
    d.pc_in = 0x1234567880000000ULL;
    d.instr_in = 0x000000ef; // JAL x1,0
    d.rs1_value_in = 0xdead; d.rs2_value_in = 0xbeef; d.immediate_in = 0;
    d.rd_idx_in = 1; d.alu_op_in = 0; d.alu_src_in = 0;
    d.mem_read_in = 0; d.mem_write_in = 0; d.csr_valid_in = 0;
    d.reg_write_in = 1; d.valid_in = 1; d.illegal_instr_in = 0;
    // A link must use the existing forwarding data path without truncation.
    d.ex_mem_forward_data_in = 0x1234567880000004ULL;
    d.mem_wb_forward_data_in = 0xabcdef0080000004ULL;
    int failed = 0, checks = 0;
    auto check = [&](bool ok, const char* msg) {
        ++checks; if (!ok) { ++failed; std::cerr << "[FAIL] " << msg << '\n'; }
    };
    for (uint32_t instr : {0x000000efu, 0x000080e7u}) {
        d.instr_in = instr;
        for (int sel = 0; sel < 3; ++sel) {
            d.forward_a_in = sel; d.forward_b_in = sel; d.eval();
            check(d.alu_result_out == d.pc_in + 4 && d.reg_write_out &&
                  !d.mem_read_out && !d.mem_write_out, "Jump link is 64-bit PC+4");
            uint64_t expected = sel == 0 ? d.rs1_value_in : sel == 1 ?
                d.mem_wb_forward_data_in : d.ex_mem_forward_data_in;
            check(d.forwarded_rs1_out == expected, "Jump target operand forwarded");
        }
    }
    // Consume link on either ALU input through both bypass paths.
    d.instr_in = 0x002081b3; d.alu_src_in = 0;
    for (int sel = 1; sel < 3; ++sel) {
        d.forward_a_in = sel; d.forward_b_in = sel; d.eval();
        uint64_t link = sel == 1 ? d.mem_wb_forward_data_in : d.ex_mem_forward_data_in;
        check(d.alu_result_out == link + link, "ALU consumes forwarded link on both inputs");
    }
    d.instr_in = 0x000000ef;
    d.pc_in = UINT64_MAX - 3; d.eval();
    check(d.alu_result_out == 0, "PC+4 wraps at XLEN");
    d.valid_in = 0; d.eval();
    check(!d.reg_write_out, "Invalid jump does not write");
    d.valid_in = 1; d.illegal_instr_in = 1; d.eval();
    check(!d.reg_write_out, "Illegal jump does not write");
    std::cout << "Tests run: " << checks << "\nTests failed: " << failed << '\n';
    return failed ? 1 : 0;
}
