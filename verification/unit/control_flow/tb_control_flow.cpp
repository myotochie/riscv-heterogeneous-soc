
#include "Vcontrol_flow.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(
    Vcontrol_flow& dut,
    bool reset,
    bool illegal_instr,
    bool is_branch,
    bool is_jal,
    bool is_jalr,
    bool branch_taken,
    uint64_t branch_target,
    uint64_t jal_target,
    uint64_t jalr_target,
    bool expected_redirect,
    uint64_t expected_target,
    bool expected_error,
    const char* name
) {
    dut.reset = reset;
    dut.illegal_instr = illegal_instr;
    dut.is_branch = is_branch;
    dut.is_jal = is_jal;
    dut.is_jalr = is_jalr;
    dut.branch_taken = branch_taken;
    dut.branch_target = branch_target;
    dut.jal_target = jal_target;
    dut.jalr_target = jalr_target;
    dut.eval();

    ++tests_run;

    const bool pass =
        dut.redirect == expected_redirect &&
        dut.redirect_target == expected_target &&
        dut.control_error == expected_error;

    if (pass) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | redirect=" << static_cast<int>(dut.redirect)
                  << " expected=" << expected_redirect
                  << " target=0x" << std::hex << dut.redirect_target
                  << " expected_target=0x" << expected_target
                  << std::dec
                  << " error=" << static_cast<int>(dut.control_error)
                  << " expected_error=" << expected_error << '\n';
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcontrol_flow dut{};

    check(dut, false, false, false, false, false, false,
          0x1000, 0x2000, 0x3000,
          false, 0, false, "No control transfer");

    check(dut, false, false, true, false, false, true,
          0x1000, 0x2000, 0x3000,
          true, 0x1000, false, "Taken branch");

    check(dut, false, false, true, false, false, false,
          0x1000, 0x2000, 0x3000,
          false, 0, false, "Not-taken branch");

    check(dut, false, false, false, true, false, false,
          0x1000, 0x2000, 0x3000,
          true, 0x2000, false, "JAL redirect");

    check(dut, false, false, false, false, true, false,
          0x1000, 0x2000, 0x3000,
          true, 0x3000, false, "JALR redirect");

    check(dut, true, false, false, true, false, false,
          0x1000, 0x2000, 0x3000,
          false, 0, false, "Reset suppresses redirect");

    check(dut, false, true, false, true, false, false,
          0x1000, 0x2000, 0x3000,
          false, 0, false, "Illegal instruction suppresses redirect");

    check(dut, false, false, true, true, false, true,
          0x1000, 0x2000, 0x3000,
          false, 0, true, "Branch and JAL conflict");

    check(dut, false, false, false, true, true, false,
          0x1000, 0x2000, 0x3000,
          false, 0, true, "JAL and JALR conflict");

    check(dut, false, false, true, true, true, true,
          0x1000, 0x2000, 0x3000,
          false, 0, true, "All transfer signals conflict");

    std::cout << "\nTests run: " << tests_run
              << "\nTests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
