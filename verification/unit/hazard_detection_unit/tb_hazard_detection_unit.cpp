#include "Vhazard_detection_unit.h"
#include "verilated.h"

#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

void check(Vhazard_detection_unit& dut,
           bool expected,
           const char* name) {
    dut.eval();

    ++tests_run;

    const bool actual_stall_pc = dut.stall_pc != 0;
    const bool actual_stall_if_id = dut.stall_if_id != 0;
    const bool actual_flush_id_ex = dut.flush_id_ex != 0;

    const bool passed =
        actual_stall_pc == expected &&
        actual_stall_if_id == expected &&
        actual_flush_id_ex == expected;

    std::cout << (passed ? "[PASS] " : "[FAIL] ")
              << name
              << " | expected=" << expected
              << " pc=" << actual_stall_pc
              << " if_id=" << actual_stall_if_id
              << " id_ex_flush=" << actual_flush_id_ex
              << '\n';

    if (!passed)
        ++tests_failed;
}

void defaults(Vhazard_detection_unit& dut) {
    dut.rs1_idx_id = 1;
    dut.rs2_idx_id = 2;
    dut.uses_rs1_id = 1;
    dut.uses_rs2_id = 1;
    dut.valid_id = 1;

    dut.rd_idx_ex = 5;
    dut.mem_read_ex = 1;
    dut.valid_ex = 1;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vhazard_detection_unit dut{};

    defaults(dut);
    check(dut, false, "No dependency");

    defaults(dut);
    dut.rs1_idx_id = 5;
    check(dut, true, "RAW dependency on rs1");

    defaults(dut);
    dut.rs2_idx_id = 5;
    check(dut, true, "RAW dependency on rs2");

    defaults(dut);
    dut.rs1_idx_id = 5;
    dut.rs2_idx_id = 5;
    check(dut, true, "RAW dependency on both operands");

    defaults(dut);
    dut.rd_idx_ex = 0;
    dut.rs1_idx_id = 0;
    check(dut, false, "Ignore destination x0");

    defaults(dut);
    dut.rs1_idx_id = 5;
    dut.valid_id = 0;
    check(dut, false, "Invalid ID instruction");

    defaults(dut);
    dut.rs1_idx_id = 5;
    dut.valid_ex = 0;
    check(dut, false, "Invalid EX instruction");

    defaults(dut);
    dut.rs1_idx_id = 5;
    dut.mem_read_ex = 0;
    check(dut, false, "EX instruction is not a load");

    defaults(dut);
    dut.rs1_idx_id = 5;
    dut.uses_rs1_id = 0;
    check(dut, false, "Matching rs1 is not used");

    defaults(dut);
    dut.rs2_idx_id = 5;
    dut.uses_rs2_id = 0;
    check(dut, false, "Matching rs2 is not used");

    defaults(dut);
    dut.rs1_idx_id = 3;
    dut.rs2_idx_id = 4;
    check(dut, false, "Used sources do not match");

    defaults(dut);
    dut.rs1_idx_id = 5;
    dut.rs2_idx_id = 4;
    check(dut, true, "Only one used source matches");

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
