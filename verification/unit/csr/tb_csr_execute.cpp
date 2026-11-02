#include "Vcsr_execute.h"
#include "verilated.h"

#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <string>

static int tests_run = 0;
static int tests_failed = 0;

void check(bool condition, const std::string& name) {
    ++tests_run;

    if (condition) {
        std::cout << "[PASS] " << name << "\n";
    } else {
        ++tests_failed;
        std::cerr << "[FAIL] " << name << "\n";
    }
}

void test_operation(
    Vcsr_execute& dut,
    uint8_t funct3,
    uint8_t rs1_idx,
    uint64_t rs1_value,
    uint64_t csr_old,
    uint64_t expected_new,
    bool expected_write,
    const std::string& name
) {
    dut.funct3 = funct3;
    dut.rs1_idx = rs1_idx;
    dut.rs1_value = rs1_value;
    dut.csr_old_value = csr_old;

    dut.eval();

    check(
        dut.csr_new_value == expected_new,
        name + " - new value"
    );

    check(
        static_cast<bool>(dut.csr_write_enable) == expected_write,
        name + " - write enable"
    );

    check(
        dut.csr_read_result == csr_old,
        name + " - old value"
    );
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vcsr_execute dut;

    constexpr uint64_t OLD =
        0xF0F0F0F00F0F0F0FULL;

    constexpr uint64_t RS1 =
        0x00FF00FF00FF00FFULL;

    // Six standard CSR operations.
    test_operation(
        dut, 1, 6, RS1, OLD,
        RS1, true, "CSRRW"
    );

    test_operation(
        dut, 2, 6, RS1, OLD,
        OLD | RS1, true, "CSRRS"
    );

    test_operation(
        dut, 3, 6, RS1, OLD,
        OLD & ~RS1, true, "CSRRC"
    );

    test_operation(
        dut, 5, 7, RS1, OLD,
        7, true, "CSRRWI"
    );

    test_operation(
        dut, 6, 7, RS1, OLD,
        OLD | 7ULL, true, "CSRRSI"
    );

    test_operation(
        dut, 7, 7, RS1, OLD,
        OLD & ~7ULL, true, "CSRRCI"
    );

    // Special cases: rs1=x0 or zimm=0.
    test_operation(
        dut, 1, 0, 0, OLD,
        0, true, "CSRRW with x0"
    );

    test_operation(
        dut, 2, 0, 0, OLD,
        OLD, false, "CSRRS with x0"
    );

    test_operation(
        dut, 3, 0, 0, OLD,
        OLD, false, "CSRRC with x0"
    );

    test_operation(
        dut, 6, 0, RS1, OLD,
        OLD, false, "CSRRSI with zimm=0"
    );

    test_operation(
        dut, 7, 0, RS1, OLD,
        OLD, false, "CSRRCI with zimm=0"
    );

    // Full-width RV64 checks.
    test_operation(
        dut, 2, 8,
        0x8000000000000000ULL,
        0x0000000000000001ULL,
        0x8000000000000001ULL,
        true,
        "CSRRS 64-bit high bit"
    );

    test_operation(
        dut, 3, 8,
        0x8000000000000000ULL,
        0xFFFFFFFFFFFFFFFFULL,
        0x7FFFFFFFFFFFFFFFULL,
        true,
        "CSRRC 64-bit high bit"
    );

    // Invalid funct3 must not modify the CSR.
    test_operation(
        dut, 0, 8, RS1, OLD,
        OLD, false, "Invalid funct3=000"
    );

    test_operation(
        dut, 4, 8, RS1, OLD,
        OLD, false, "Invalid funct3=100"
    );

    std::cout << "\nTests run: "
              << tests_run << "\n";

    std::cout << "Tests failed: "
              << tests_failed << "\n";

    dut.final();

    return tests_failed == 0
        ? EXIT_SUCCESS
        : EXIT_FAILURE;
}
