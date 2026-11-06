#include "Vdecoder.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

static uint32_t csr_instr(
    uint32_t csr,
    uint32_t rs1,
    uint32_t funct3,
    uint32_t rd
) {
    return (csr << 20) |
           (rs1 << 15) |
           (funct3 << 12) |
           (rd << 7) |
           0x73;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vdecoder dut;

    int tests = 0;
    int failures = 0;

    auto check = [&](bool condition, const char* message) {
        ++tests;
        std::printf("[%s] %s\n",
                    condition ? "PASS" : "FAIL", message);
        if (!condition) ++failures;
    };

    const uint32_t funct3_values[] = {
        1, 2, 3, 5, 6, 7
    };

    const char* names[] = {
        "CSRRW", "CSRRS", "CSRRC",
        "CSRRWI", "CSRRSI", "CSRRCI"
    };

    for (int i = 0; i < 6; ++i) {
        const uint32_t f = funct3_values[i];

        dut.instr = csr_instr(0x305, 5, f, 10);
        dut.eval();

        check(dut.csr_valid == 1, names[i]);
        check(dut.csr_funct3 == f, "Correct CSR funct3");
        check(dut.illegal_instr == 0, "CSR instruction legal");
        check(dut.uses_rs1 == (f < 4),
              "Correct source register dependency");
        check(dut.uses_rs2 == 0, "No rs2 dependency");
    }

    dut.instr = 0x30200073;
    dut.eval();

    check(dut.mret_valid == 1, "MRET recognized");
    check(dut.csr_valid == 0, "MRET is not CSR operation");
    check(dut.illegal_instr == 0, "MRET accepted");
    check(dut.uses_rs1 == 0, "MRET has no rs1 dependency");
    check(dut.uses_rs2 == 0, "MRET has no rs2 dependency");

    dut.instr = 0x00000073;
    dut.eval();

    check(dut.illegal_instr == 1,
          "ECALL unsupported at this stage");
    check(dut.csr_valid == 0, "ECALL not CSR operation");
    check(dut.mret_valid == 0, "ECALL not MRET");

    dut.instr = 0x00100073;
    dut.eval();

    check(dut.illegal_instr == 1,
          "EBREAK unsupported at this stage");

    dut.instr = 0x00000013;
    dut.eval();

    check(dut.csr_valid == 0, "ADDI is not CSR");
    check(dut.mret_valid == 0, "ADDI is not MRET");

    std::printf("Tests run: %d\n", tests);
    std::printf("Tests failed: %d\n", failures);

    dut.final();
    return failures == 0 ? 0 : 1;
}
