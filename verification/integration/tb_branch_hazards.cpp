#include "Vrv64_pipeline.h"
#include "verilated.h"
#include <cstdint>
#include <cstdlib>
#include <iostream>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    if (argc != 2) return 2;
    int id = std::atoi(argv[1]);
    if (id != 32 && id != 33) return 2;

    Vrv64_pipeline dut;
    dut.clk = 0;
    dut.reset = 1;
    dut.stall = 0;
    dut.flush = 0;
    dut.eval();

    for (int i = 0; i < 2; ++i) {
        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.eval();
    }

    dut.reset = 0;
    dut.eval();

    uint64_t values[32] = {};
    int writes[32] = {};
    int traps = 0;
    int pc_stalls = 0;

    bool have_previous_pc = false;
    uint64_t previous_pc = 0;

    for (int cycle = 0; cycle < 50; ++cycle) {
        dut.clk = 0;
        dut.eval();

        uint64_t current_pc = dut.pc_value;
        if (have_previous_pc && current_pc == previous_pc)
            ++pc_stalls;
        previous_pc = current_pc;
        have_previous_pc = true;

        if (dut.trap_valid_o) ++traps;

        if (dut.wb_we && dut.wb_rd != 0) {
            unsigned rd = dut.wb_rd;
            ++writes[rd];
            values[rd] = dut.wb_data;

            std::cout << "[WB] cycle=" << cycle
                      << " x" << rd
                      << "=" << values[rd] << '\n';
        }

        dut.clk = 1; dut.eval();
        dut.clk = 0; dut.eval();
    }

    int failed = 0;
    int total = 0;

    auto check = [&](bool ok, const char* label) {
        ++total;
        if (!ok) ++failed;
        std::cout << (ok ? "[PASS] " : "[FAIL] ")
                  << label << '\n';
    };

    std::cout << "\nPROGRAM_ID=" << id << '\n';

    check(traps == 0, "No unexpected trap");
    check(writes[3] == 0, "Wrong-path x3 instruction squashed");
    check(writes[4] == 1 && values[4] == 7,
          "Target instruction executes exactly once");

    if (id == 32) {
        check(writes[1] == 2 && values[1] == 6,
              "ALU result x1=6");
        check(writes[2] == 1 && values[2] == 6,
              "Branch comparison operand x2=6");
    } else {
        check(writes[1] == 1 && values[1] == 128,
              "Memory address initialized");
        check(writes[2] == 1 && values[2] == 7,
              "Stored value initialized");
        check(writes[5] == 1 && values[5] == 7,
              "LD returns stored value");
        check(pc_stalls >= 1,
              "Load-use dependency stalls PC");
    }

    std::cout << "PC hold observations: " << pc_stalls << '\n';
    std::cout << "Tests run: " << total
              << "\nTests failed: " << failed << '\n';

    dut.final();
    return failed ? 1 : 0;
}
