#include "Vforwarding_unit.h"
#include "verilated.h"

#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(bool condition, const char* name) {
    ++tests_run;

    if (condition) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name << '\n';
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vforwarding_unit dut{};

    // Initialisation
    dut.rs1_idx_ex = 1;
    dut.rs2_idx_ex = 2;

    dut.rd_idx_ex_mem = 0;
    dut.reg_write_ex_mem = 0;
    dut.mem_read_ex_mem = 0;
    dut.valid_ex_mem = 0;

    dut.rd_idx_mem_wb = 0;
    dut.reg_write_mem_wb = 0;
    dut.valid_mem_wb = 0;

    dut.eval();

    check(
        dut.forward_a == 0 && dut.forward_b == 0,
        "no dependency: use ID/EX operands"
    );

    // EX/MEM -> rs1
    dut.rd_idx_ex_mem = 1;
    dut.reg_write_ex_mem = 1;
    dut.valid_ex_mem = 1;
    dut.eval();

    check(
        dut.forward_a == 2 && dut.forward_b == 0,
        "EX/MEM forwarding to rs1"
    );

    // EX/MEM -> rs2
    dut.rd_idx_ex_mem = 2;
    dut.eval();

    check(
        dut.forward_a == 0 && dut.forward_b == 2,
        "EX/MEM forwarding to rs2"
    );

    // MEM/WB -> rs1
    dut.valid_ex_mem = 0;
    dut.rd_idx_mem_wb = 1;
    dut.reg_write_mem_wb = 1;
    dut.valid_mem_wb = 1;
    dut.eval();

    check(
        dut.forward_a == 1 && dut.forward_b == 0,
        "MEM/WB forwarding to rs1"
    );

    // MEM/WB -> rs2
    dut.rd_idx_mem_wb = 2;
    dut.eval();

    check(
        dut.forward_a == 0 && dut.forward_b == 1,
        "MEM/WB forwarding to rs2"
    );

    // EX/MEM must win over MEM/WB.
    dut.rd_idx_ex_mem = 1;
    dut.valid_ex_mem = 1;
    dut.rd_idx_mem_wb = 1;
    dut.eval();

    check(
        dut.forward_a == 2,
        "EX/MEM has priority over MEM/WB"
    );

    // Disabled register write must prevent forwarding.
    dut.reg_write_ex_mem = 0;
    dut.reg_write_mem_wb = 0;
    dut.eval();

    check(
        dut.forward_a == 0 && dut.forward_b == 0,
        "reg_write disabled prevents forwarding"
    );

    // Invalid instructions must not forward.
    dut.reg_write_ex_mem = 1;
    dut.reg_write_mem_wb = 1;
    dut.valid_ex_mem = 0;
    dut.valid_mem_wb = 0;
    dut.eval();

    check(
        dut.forward_a == 0 && dut.forward_b == 0,
        "invalid instructions cannot forward"
    );

    // x0 must never be forwarded.
    dut.rs1_idx_ex = 0;
    dut.rs2_idx_ex = 0;
    dut.rd_idx_ex_mem = 0;
    dut.rd_idx_mem_wb = 0;
    dut.valid_ex_mem = 1;
    dut.valid_mem_wb = 1;
    dut.eval();

    check(
        dut.forward_a == 0 && dut.forward_b == 0,
        "x0 is never forwarded"
    );


    // LD in EX/MEM: ALU result is an address, not load data.
    dut.rs1_idx_ex = 5;
    dut.rs2_idx_ex = 5;

    dut.rd_idx_ex_mem = 5;
    dut.reg_write_ex_mem = 1;
    dut.mem_read_ex_mem = 1;
    dut.valid_ex_mem = 1;

    dut.rd_idx_mem_wb = 0;
    dut.reg_write_mem_wb = 0;
    dut.valid_mem_wb = 0;

    dut.eval();

    check(
        dut.forward_a == 0 && dut.forward_b == 0,
        "LD in EX/MEM must not forward address"
    );

    // MEM/WB remains available when EX/MEM contains a load.
    dut.rd_idx_mem_wb = 5;
    dut.reg_write_mem_wb = 1;
    dut.valid_mem_wb = 1;

    dut.eval();

    check(
        dut.forward_a == 1 && dut.forward_b == 1,
        "MEM/WB forwarding remains available for load dependency"
    );

    // An ALU instruction in EX/MEM must still have priority.
    dut.mem_read_ex_mem = 0;

    dut.eval();

    check(
        dut.forward_a == 2 && dut.forward_b == 2,
        "ALU EX/MEM forwarding retains priority"
    );

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
