#include "Vrv64_pipeline.h"
#if __has_include("Vrv64_pipeline___024root.h")
#include "Vrv64_pipeline___024root.h"
#define CF03_ROOTP(dut) ((dut).rootp)
#else
#define CF03_ROOTP(dut) (&(dut))
#endif
#include "verilated.h"
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <map>

static int failed = 0;
static int checks = 0;
static void check(bool ok, const char* name) {
    ++checks;
    if (!ok) ++failed;
    std::cout << (ok ? "[PASS] " : "[FAIL] ") << name << '\n';
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    if (argc < 2) return 2;
    const int id = std::atoi(argv[1]);
    const int mode = argc > 2 ? std::atoi(argv[2]) : 0;
    if (id < 36 || id > 47) return 2;
    constexpr uint64_t base = 0x80000000ULL;
    Vrv64_pipeline d;
    auto* r = CF03_ROOTP(d);
    d.clk = 0; d.reset = 1; d.stall = 0; d.flush = 0; d.eval();
    for (int k = 0; k < 2; ++k) {
        d.clk = 1; d.eval(); d.clk = 0; d.eval();
    }
    d.reset = 0; d.eval();
    int writes[32] = {};
    uint64_t values[32] = {};
    std::map<uint64_t, int> retired;
    int traps = 0, alu_ex_bypass = 0, csr_ex_bypass = 0, wb_bypass = 0;
    int load_use_stalls = 0;
    int jalr_trap_collisions = 0;
    int mrets = 0, injected = 0, held = 0, after_cancel = 0;
    uint64_t epc = 0, tval = 0, cause = 0;
    const int cycles = 180;
    for (int c = 0; c < cycles; ++c) {
        d.clk = 0; d.eval();
        bool ex_valid = r->rv64_pipeline__DOT__u_frontend__DOT__id_ex_valid;
        uint32_t ex_instr = r->rv64_pipeline__DOT__u_frontend__DOT__id_ex_instr;
        bool jump = (ex_instr & 0x7f) == 0x6f || (ex_instr & 0x707f) == 0x67;
        // Hold/cancel the first jump, or the faulting jump in MEM.
        bool jalr_mode = mode >= 7 && mode <= 9;
        bool trigger = jalr_mode ?
            (ex_valid && (ex_instr & 0x707f) == 0x67 &&
             r->rv64_pipeline__DOT__u_frontend__DOT__id_ex_pc == base + 0x50) :
            (mode <= 3 ? (ex_valid && jump) :
             bool(r->rv64_pipeline__DOT__ex_mem_target_misaligned));
        if (mode && !injected && trigger) injected = 1;
        if (injected == 1) {
            if (mode == 1 || mode == 4 || mode == 7) {
                d.stall = held < 3;
                if (d.stall) ++held; else injected = 2;
            } else {
                d.flush = mode == 2 || mode == 5 || mode == 8;
                d.reset = mode == 3 || mode == 6 || mode == 9;
                injected = 2;
            }
            d.eval();
        }
        if (r->rv64_pipeline__DOT__u_frontend__DOT__hazard_stall_pc && !d.stall)
            ++load_use_stalls;
        if (d.flush || d.reset || d.stall) {
            check(!d.wb_we && !r->rv64_pipeline__DOT__csr_commit_we,
                  "Control suppression blocks GPR and CSR commits");
            check(!r->rv64_pipeline__DOT__u_data_memory__DOT__mem_write || d.reset,
                  "Stall/flush suppress memory write enable; reset suppresses RAM write edge");
        }
        const uint64_t pc_before = d.pc_value;
        const bool trap = d.trap_valid_o;
        if (trap && ex_valid && (ex_instr & 0x707f) == 0x67) {
            ++jalr_trap_collisions;
            check(!r->rv64_pipeline__DOT__u_frontend__DOT__ex_branch_redirect,
                  "Older MEM trap suppresses simultaneous EX JALR");
        }
        if (trap) {
            ++traps; epc = d.trap_epc_o; cause = d.trap_cause_o; tval = d.trap_tval_o;
        }
        if (d.stall) {
            check(!d.wb_we && !trap && !r->rv64_pipeline__DOT__u_frontend__DOT__ex_branch_redirect,
                  "External stall suppresses WB, trap and EX redirect");
        }
        if (d.wb_we) {
            if ((d.mem_wb_instr & 0x7f) == 0x6f ||
                (d.mem_wb_instr & 0x707f) == 0x67)
                check(d.wb_data == d.mem_wb_pc + 4, "Retiring jump writes its own PC+4");
            ++writes[d.wb_rd]; values[d.wb_rd] = d.wb_data;
            check(d.wb_rd != 0, "No architectural write to x0");
        }
        if (d.mem_wb_valid && !d.stall && !d.flush && !d.reset) {
            ++retired[d.mem_wb_pc];
            if (d.mem_wb_instr == 0x30200073) ++mrets;
        }
        if (ex_valid && (ex_instr & 0x707f) == 0x67 && !d.stall && !d.flush && !d.reset) {
            unsigned sel = r->rv64_pipeline__DOT__u_frontend__DOT__forward_a;
            if (sel == 2) {
                if (r->rv64_pipeline__DOT__ex_mem_csr_valid) ++csr_ex_bypass;
                else ++alu_ex_bypass;
            }
            if (sel == 1) ++wb_bypass;
        }
        bool redirect = r->rv64_pipeline__DOT__u_frontend__DOT__ex_branch_redirect;
        uint64_t target = r->rv64_pipeline__DOT__u_frontend__DOT__ex_branch_target;
        d.clk = 1; d.eval();
        if (redirect) {
            check(d.pc_value == target, "EX redirect selects computed target");
            check(!r->rv64_pipeline__DOT__u_frontend__DOT__id_ex_valid &&
                  !r->rv64_pipeline__DOT__u_frontend__DOT__if_id_valid,
                  "EX redirect flushes both younger pipeline slots");
        }
        if (d.stall) check(d.pc_value == pc_before, "PC held during external stall");
        if (trap) check(d.pc_value == (id == 42 ? base + 0x180 : base + 0x100),
                        "Trap PC selects effective MTVEC");
        if (ex_valid && jump && !d.stall && !d.flush && !d.reset && mode <= 1)
            check((d.pc_value & 3) == 0, "PC remains word aligned");
        d.clk = 0; d.eval();
        if (d.flush || d.reset) { d.flush = 0; d.reset = 0; d.eval(); }
        if (injected == 2 && (mode == 2 || mode == 3 || mode == 5 || mode == 6 || mode == 8 || mode == 9)) {
            // Observe the cancellation window before sequential fetch reaches
            // the same instruction again after reset.
            if (++after_cancel == 3) break;
        }
    }
    std::cout << "PROGRAM_ID=" << id << " mode=" << mode << '\n';
    if (mode == 8 || mode == 9) {
        check(injected == 2, "Flush/reset injected at EX JALR return");
        check(retired[base + 0x50] == 0, "Canceled JALR does not retire");
        check(writes[10] == 0, "Canceled JALR does not reach caller");
        check(traps == 0, "Canceled JALR does not trap");
    } else if (mode == 2 || mode == 3) {
        check(injected == 2, "Flush/reset injected at EX jump");
        check(writes[1] == 0, "Canceled jump never writes link");
        check(retired[base + 0x40] == 0, "Canceled jump target does not retire");
        check(traps == 0, "No trap on canceled jump");
    } else if (mode == 5 || mode == 6) {
        check(injected == 2, "Flush/reset injected at MEM jump fault");
        check(traps == 0, "Canceled fault does not update trap state");
        check(d.csr_mcause_o == 0 && d.csr_mepc_o == 0 && d.csr_mtval_o == 0,
              "Canceled fault leaves reset trap CSRs");
        check(writes[1] == 0, "Canceled fault never writes link");
    } else {
        if (mode) check(injected == 2 && held == 3, "Three-cycle stall exercised");
        if (id == 36) {
            check(traps == 0, "No trap in nested call program");
            check(writes[1] == 2 && values[1] == base + 8, "Saved RA restored");
            check(writes[10] == 1 && values[10] == base + 8, "Outer function returns");
            check(values[11] == base + 8 && values[12] == base + 0x4c, "Both callees see links");
            check(values[13] == base + 0x98, "rd=rs1 uses old base, writes new link");
            check(values[15] == base + 0xbc, "Negative-offset JALR writes PC+4");
            check(writes[30] == 0, "Wrong-path GPR writes squashed");
            check(d.csr_mtvec_o == base + 0x100, "Wrong-path CSR does not change MTVEC");
            check(retired[base + 0x54] == 0 && retired[base + 0x68] == 0,
                  "Wrong-path store and CSR squashed");
            check(retired[base + 0x50] == 1 && retired[base + 0x64] == 1, "Returns retire once");
        } else if (id == 37) {
            check(traps == 0 && values[7] == base + 0x4c && values[11] == base + 0x40,
                  "ALU/CSR/load targets and links correct");
            check(alu_ex_bypass > 0 && csr_ex_bypass > 0 && wb_bypass > 0,
                  "EX/MEM ALU, EX/MEM CSR and MEM/WB forwarding exercised");
            check(load_use_stalls == 1, "Exactly one load-use interlock before JALR");
            check(values[12] == 96, "Dependency program reaches final marker");
        } else if (id == 38 || id == 39 || id == 42) {
            uint64_t expected_pc = base + (id == 38 ? 4 : id == 39 ? 0x24 : 0x28);
            uint64_t expected_target = base + (id == 38 ? 6 : id == 39 ? 0x22 : 0x2a);
            check(traps == 1 && epc == expected_pc && cause == 0 && tval == expected_target,
                  "One precise instruction-address-misaligned event");
            check(d.csr_mepc_o == epc && d.csr_mcause_o == 0 && d.csr_mtval_o == tval,
                  "Architectural trap CSRs match event");
            check(values[10] == 123 && writes[30] == 0 && writes[31] == 0,
                  "Correct handler executes, wrong path squashed");
            if (id == 38) check(writes[1] == 0 && values[2] == 7, "Fault suppresses link and preserves older WB");
            if (id == 39) check(writes[1] == 1 && values[1] == base + 8, "Faulting rd=rs1 preserves previous link");
            if (id != 42) check(values[11] == 0 && values[12] == base + 0x100, "Younger store and CSR have no effects");
            if (id == 42) check(writes[5] == 0 && d.csr_mtvec_o == base + 0x180, "Older MTVEC commits, faulting link suppressed");
        } else if (id == 40 || id == 47) {
            if (id == 47) check(jalr_trap_collisions == 1, "JALR/MEM trap collision exercised");
            check(traps == 1 && cause == 4 && epc == base + 4 && tval == 65,
                  "Older memory fault wins over EX jump");
            check(writes[5] == 0 && writes[30] == 0 && writes[31] == 0 && values[10] == 123,
                  "Younger link, sequential path and target canceled");
        } else if (id == 41) {
            check(traps == 1 && cause == 4 && mrets == 1, "MRET suppresses younger MEM jump fault");
            check(values[7] == 7 && values[8] == 8, "MRET resumes expected PC");
            check(writes[11] == 0 && writes[12] == 0 && writes[30] == 0, "MRET cancels both younger jump links and target");
        } else if (id == 43) {
            check(traps == 0 && writes[5] == 0 && values[10] == 123,
                  "Reserved JALR remains side-effect free and follows existing illegal policy");
        } else if (id == 45) {
            check(traps == 0 && load_use_stalls == 0 && values[10] == base + 8,
                  "JAL immediate fields never create a false load-use dependency");
        } else if (id == 46) {
            check(traps == 1 && cause == 0 && epc == base + 8 && tval == base + 10,
                  "Only taken branch faults on misaligned target");
            check(retired[base + 4] == 1 && writes[30] == 0 && values[10] == 123,
                  "Non-taken branch retires and handler executes");
        } else if (id == 44) {
            check(traps == 0 && writes[30] == 0 && values[10] == base + 0x6c,
                  "Newest producer wins and MEM/WB target works");
            check(alu_ex_bypass > 0 && wb_bypass > 0, "Both operand forwarding paths exercised");
        }
    }
    d.final();
    std::cout << "Tests run: " << checks << "\nTests failed: " << failed << '\n';
    return failed ? 1 : 0;
}
