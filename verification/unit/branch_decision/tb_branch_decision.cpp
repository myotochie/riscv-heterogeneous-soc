
#include "Vbranch_decision.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(
    Vbranch_decision& dut,
    uint8_t funct3,
    uint64_t rs1,
    uint64_t rs2,
    bool is_branch,
    bool is_jal,
    bool is_jalr,
    bool expected_taken,
    bool expected_illegal,
    const char* name
) {
    dut.funct3 = funct3;
    dut.rs1_value = rs1;
    dut.rs2_value = rs2;
    dut.is_branch = is_branch;
    dut.is_jal = is_jal;
    dut.is_jalr = is_jalr;
    dut.eval();

    ++tests_run;

    if (dut.branch_taken == expected_taken &&
        dut.illegal_control == expected_illegal) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name
                  << " | taken=" << static_cast<int>(dut.branch_taken)
                  << " expected=" << expected_taken
                  << " illegal=" << static_cast<int>(dut.illegal_control)
                  << " expected_illegal=" << expected_illegal << '\n';
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vbranch_decision dut{};

    check(dut, 0b000, 10, 10, true, false, false,
          true, false, "BEQ equal");

    check(dut, 0b000, 10, 11, true, false, false,
          false, false, "BEQ unequal");

    check(dut, 0b001, 10, 11, true, false, false,
          true, false, "BNE unequal");

    check(dut, 0b100, UINT64_MAX, 1, true, false, false,
          true, false, "BLT signed negative");

    check(dut, 0b101, 1, UINT64_MAX, true, false, false,
          true, false, "BGE signed positive versus negative");

    check(dut, 0b110, 1, 2, true, false, false,
          true, false, "BLTU unsigned");

    check(dut, 0b111, 3, 2, true, false, false,
          true, false, "BGEU unsigned");

    check(dut, 0b010, 10, 10, true, false, false,
          false, true, "Unsupported branch funct3");

    check(dut, 0, 0, 0, false, true, false,
          true, false, "JAL always taken");

    check(dut, 0, 0, 0, false, false, true,
          true, false, "JALR always taken");

    check(dut, 0, 0, 0, false, false, false,
          false, false, "No control-flow instruction");

    std::cout << "\nTests run: " << tests_run
              << "\nTests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
