#include "Vdecode_stage.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

static int tests_run = 0;
static int tests_failed = 0;

enum AluOp : uint8_t {
    ALU_ADD = 0,
    ALU_SUB = 1
};

uint32_t encode_r_type(
    uint8_t funct7,
    uint8_t rs2,
    uint8_t rs1,
    uint8_t funct3,
    uint8_t rd
) {
    return (uint32_t(funct7) << 25)
         | (uint32_t(rs2) << 20)
         | (uint32_t(rs1) << 15)
         | (uint32_t(funct3) << 12)
         | (uint32_t(rd) << 7)
         | 0x33;
}

uint32_t encode_addi(int16_t imm, uint8_t rs1, uint8_t rd) {
    return (uint32_t(uint16_t(imm) & 0x0FFF) << 20)
         | (uint32_t(rs1) << 15)
         | (uint32_t(rd) << 7)
         | 0x13;
}

void check(bool condition, const char* name) {
    ++tests_run;

    if (condition) {
        std::cout << "[PASS] " << name << '\n';
    } else {
        ++tests_failed;
        std::cout << "[FAIL] " << name << '\n';
    }
}

void write_register(
    Vdecode_stage& dut,
    uint8_t address,
    uint64_t value
) {
    dut.clk = 0;
    dut.wb_we = 1;
    dut.wb_rd = address;
    dut.wb_data = value;
    dut.eval();

    dut.clk = 1;
    dut.eval();

    dut.clk = 0;
    dut.wb_we = 0;
    dut.eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vdecode_stage dut{};

    dut.clk = 0;
    dut.pc_in = UINT64_C(0x80000000);
    dut.instr_in = encode_addi(5, 0, 1);
    dut.valid_in = 1;
    dut.wb_we = 0;
    dut.wb_rd = 0;
    dut.wb_data = 0;
    dut.eval();

    // 1. ADDI x1, x0, 5.
    check(
        dut.pc_out == UINT64_C(0x80000000) &&
        dut.instr_out == dut.instr_in &&
        dut.rs1_idx_out == 0 &&
        dut.rd_idx_out == 1 &&
        dut.rs1_value_out == 0 &&
        dut.immediate_out == 5 &&
        dut.alu_op_out == ALU_ADD &&
        dut.alu_src_out == 1 &&
        dut.reg_write_out == 1 &&
        dut.illegal_instr_out == 0 &&
        dut.valid_out == 1,
        "ADDI decoding and PC propagation"
    );

    // 2. Initialize x1 and x2 through the WB interface.
    write_register(dut, 1, 42);
    write_register(dut, 2, 99);

    // ADD x3, x1, x2.
    dut.instr_in = encode_r_type(0x00, 2, 1, 0b000, 3);
    dut.eval();

    check(
        dut.rs1_idx_out == 1 &&
        dut.rs2_idx_out == 2 &&
        dut.rd_idx_out == 3 &&
        dut.rs1_value_out == 42 &&
        dut.rs2_value_out == 99 &&
        dut.alu_op_out == ALU_ADD &&
        dut.alu_src_out == 0 &&
        dut.reg_write_out == 1 &&
        dut.illegal_instr_out == 0,
        "ADD decoding and register reads"
    );

    // 3. SUB x4, x2, x1.
    dut.instr_in = encode_r_type(0x20, 1, 2, 0b000, 4);
    dut.eval();

    check(
        dut.rs1_value_out == 99 &&
        dut.rs2_value_out == 42 &&
        dut.alu_op_out == ALU_SUB &&
        dut.reg_write_out == 1,
        "SUB decoding"
    );

    // 4. Sign extension of a negative immediate.
    dut.instr_in = encode_addi(-1, 1, 5);
    dut.eval();

    check(
        dut.rs1_value_out == 42 &&
        dut.immediate_out == UINT64_MAX &&
        dut.alu_src_out == 1 &&
        dut.reg_write_out == 1,
        "ADDI negative immediate"
    );

    // 5. x0 cannot be modified through WB.
    write_register(dut, 0, UINT64_MAX);
    dut.instr_in = encode_addi(7, 0, 6);
    dut.eval();

    check(
        dut.rs1_value_out == 0,
        "x0 write protection"
    );

    // 6. Unsupported instruction.
    dut.instr_in = 0xFFFFFFFF;
    dut.valid_in = 1;
    dut.eval();

    check(
        dut.illegal_instr_out == 1 &&
        dut.reg_write_out == 0 &&
        dut.alu_src_out == 0 &&
        dut.valid_out == 1,
        "illegal instruction blocks register write"
    );

    // 7. Invalid instruction slot (pipeline bubble).
    dut.instr_in = encode_addi(12, 1, 7);
    dut.valid_in = 0;
    dut.eval();

    check(
        dut.valid_out == 0 &&
        dut.reg_write_out == 0 &&
        dut.alu_src_out == 0 &&
        dut.illegal_instr_out == 0,
        "invalid slot disables control signals"
    );

    // 8. Decode outputs change without a clock edge.
    dut.valid_in = 1;
    dut.pc_in = UINT64_C(0x80000004);
    dut.instr_in = encode_addi(20, 2, 8);
    dut.eval();

    check(
        dut.pc_out == UINT64_C(0x80000004) &&
        dut.rd_idx_out == 8 &&
        dut.rs1_value_out == 99 &&
        dut.immediate_out == 20 &&
        dut.reg_write_out == 1,
        "combinational decode without clock edge"
    );

    std::cout << "\nTests run: " << tests_run << '\n';
    std::cout << "Tests failed: " << tests_failed << '\n';

    return tests_failed == 0 ? 0 : 1;
}
