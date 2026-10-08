#include "Valu.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

enum class AluOp : uint8_t {
ADD  = 0,
SUB  = 1,
AND  = 2,
OR   = 3,
XOR  = 4,
SLL  = 5,
SRL  = 6,
SRA  = 7,
SLT  = 8,
SLTU = 9
};

static int tests_run = 0;
static int tests_failed = 0;

void check_result(
Valu& dut,
uint64_t a,
uint64_t b,
AluOp op,
uint64_t expected,
const char* name
) {
dut.a = a;
dut.b = b;
dut.op = static_cast<uint8_t>(op);


dut.eval();

tests_run++;

if (dut.result != expected) {
    std::cerr << "[FAIL] " << name
              << " | expected=0x" << std::hex << expected
              << " got=0x" << dut.result
              << std::dec << '\n';

    tests_failed++;
} else {
    std::cout << "[PASS] " << name << '\n';
}


}

int main(int argc, char** argv) {
Verilated::commandArgs(argc, argv);


Valu dut;

check_result(dut, 10, 20, AluOp::ADD, 30, "ADD");
check_result(dut, 20, 10, AluOp::SUB, 10, "SUB");

check_result(
    dut,
    0xFF00ULL,
    0x0F0FULL,
    AluOp::AND,
    0x0F00ULL,
    "AND"
);

check_result(
    dut,
    0xF000ULL,
    0x0F00ULL,
    AluOp::OR,
    0xFF00ULL,
    "OR"
);

check_result(
    dut,
    0xFF00ULL,
    0x0F00ULL,
    AluOp::XOR,
    0xF000ULL,
    "XOR"
);

check_result(
    dut,
    1,
    4,
    AluOp::SLL,
    16,
    "SLL"
);

check_result(
    dut,
    16,
    2,
    AluOp::SRL,
    4,
    "SRL"
);

check_result(
    dut,
    static_cast<uint64_t>(-16LL),
    2,
    AluOp::SRA,
    static_cast<uint64_t>(-4LL),
    "SRA"
);

check_result(
    dut,
    static_cast<uint64_t>(-5LL),
    3,
    AluOp::SLT,
    1,
    "SLT signed"
);

check_result(
    dut,
    3,
    5,
    AluOp::SLT,
    1,
    "SLT signed positive"
);

check_result(
    dut,
    5,
    3,
    AluOp::SLT,
    0,
    "SLT signed false"
);

check_result(
    dut,
    1,
    2,
    AluOp::SLTU,
    1,
    "SLTU"
);

check_result(
    dut,
    0xFFFFFFFFFFFFFFFFULL,
    1,
    AluOp::SLTU,
    0,
    "SLTU high-bit"
);

std::cout << '\n';
std::cout << "Tests run: " << tests_run << '\n';
std::cout << "Tests failed: " << tests_failed << '\n';

return tests_failed == 0 ? 0 : 1;


}

