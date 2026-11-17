# RISC-V Heterogeneous SoC

A research-oriented implementation and exploration of a multicore RISC-V System-on-Chip for dataflow-oriented applications.

The project aims to develop a complete hardware/software stack covering processor architecture, cache hierarchy, cache coherence, interconnects, DMA, accelerator integration, FPGA implementation, firmware, and Linux SMP.

## Objectives

The main objectives are:

* design and implement a multicore RISC-V architecture;
* explore shared-memory multicore architectures;
* implement and evaluate cache coherence;
* study interconnect and NoC architectures;
* integrate DMA and hardware accelerators;
* develop a reproducible verification environment;
* validate the architecture through FPGA implementation;
* boot and run Linux in SMP configuration;
* evaluate performance using quantitative architectural metrics.

## Target Architecture

The initial architectural target is:

| Component       | Initial target                           |
| --------------- | ---------------------------------------- |
| ISA             | RV64GC                                   |
| Privilege modes | M / S / U                                |
| Virtual memory  | Sv39                                     |
| CPU cores       | 4                                        |
| Pipeline        | In-order, approximately 5 stages         |
| L1 cache        | Private I-cache + D-cache per core       |
| L2 cache        | Shared                                   |
| Coherence       | MESI                                     |
| Interconnect    | Coherent interconnect → packet-based NoC |
| DMA             | AXI4 / AXI4-Stream                       |
| Memory          | DDR4-oriented FPGA target                |
| Interrupts      | PLIC-class controller                    |
| Accelerator     | Custom hardware accelerator              |
| FPGA target     | Zynq-7000-class platform initially       |
| Software        | Firmware + Linux SMP                     |

The detailed architectural rationale is documented in:

`docs/architecture/system-spec-v0.1.md`

## Development Methodology

The project follows a specification-driven hardware/software development methodology:

```text
Architecture
     ↓
System specification
     ↓
Microarchitecture
     ↓
RTL implementation
     ↓
Unit verification
     ↓
Integration verification
     ↓
FPGA implementation
     ↓
Firmware
     ↓
Linux SMP
     ↓
Performance evaluation
```

Architectural decisions are documented before implementation whenever possible.

## Verification

The verification strategy will combine:

* SystemVerilog assertions;
* directed tests;
* cocotb-based verification;
* Verilator simulation;
* reference models;
* architectural comparison against established RISC-V platforms where appropriate;
* FPGA validation.

The project will progressively move from unit-level verification to complete system validation.

## Performance Evaluation

The architecture will be evaluated using measurable metrics including:

* maximum operating frequency;
* CPI / IPC;
* cache hit and miss rates;
* memory latency;
* memory bandwidth;
* interconnect / NoC latency;
* DMA throughput;
* accelerator throughput;
* accelerator speedup;
* hardware utilization.

## Repository Structure

The repository is organized to separate architecture, RTL, software, verification, and FPGA implementation:

```text
riscv-heterogeneous-soc/
├── docs/
│   └── architecture/
├── rtl/
├── sim/
├── verification/
├── firmware/
├── software/
├── fpga/
├── scripts/
├── tests/
├── LICENSE
├── README.md
└── .gitignore
```

Directories will be introduced progressively as their corresponding components are implemented.

## Main Technologies

The project is expected to use:

* SystemVerilog
* C / C++
* Python
* Verilator
* cocotb
* CMake
* GNU Make
* RISC-V toolchains
* Vivado
* FPGA development tools

## Project Status

The implemented design is currently a **single RV64 five-stage experimental
core**, with a partial integer ISA, LD/SD, forwarding, machine CSR support,
precise data-memory traps, conditional branches, and JAL/JALR integrated into
main after successful CI. The RV64GC multicore/cache/Linux table above is a **future target**,
not a statement of implemented or validated capabilities.

CF-01 (`bc4a80b`) and CF-02 (`81eb817`) precede the CF-03 implementation on
`feat/rv64-program-loader`. CF-03 has passed local verification. Its publication
and integration status is recorded separately in the project progress log.
Current limitations and evidence are tracked in [PROJECT_PROGRESS](docs/PROJECT_PROGRESS.md) and
[ARCHITECTURE_OVERVIEW](docs/architecture/ARCHITECTURE_OVERVIEW.md).

### Reproduce the complete RTL regression

Install/provide Bash, Python 3, a native C++ compiler, Make, Verilator >=5
and GNU RISC-V bare-metal Binutils (as, ld, objcopy, objdump, readelf).
The complete regression also requires RISC-V GCC for the CF-05.1 code-generation
inspection suite; this suite does not execute its C probes on the RTL. The CI
reference version is 5.040; runners never install tools on the local system.

```bash
VERILATOR=/path/to/verilator-5.040/bin/verilator \
  bash scripts/run_clean_regression.sh
```

The runner copies tracked and new non-ignored sources into a clean temporary
snapshot, generates required memory fixtures, runs all active suites, and
records tool versions, source SHA256 hashes, logs and a PASS/FAIL summary.
It returns failure if any suite fails. Two obsolete load-invalid benches are
catalogued as [historical](verification/historical/README.md), not counted as
passing tests. The CSR unit bench is active again.

For a focused study:

```bash
VERILATOR=verilator bash verification/scripts/run_jump_unit.sh
VERILATOR=verilator bash verification/scripts/run_jump_pipeline.sh
```

Read the [CF-03 architecture](docs/architecture/cf03-jumps.md),
[implementation guide](docs/implementation/cf03-jumps.md),
[verification dossier](docs/verification/cf03-jumps.md),
[learning guide](docs/learning/cf03-jumps.md) and
[decision log](docs/decisions/cf03-jumps.md).

Simulation success is not full ISA conformance, synthesis, timing closure,
FPGA validation or a multicore demonstration. CF-04.1/2 added an optional external instruction HEX backend in d336ca7, while
preserving integrated programs 0–47. The format, configuration and limitations
are described in the [CF-04 architecture](docs/architecture/cf04-program-loader.md).
CF-04.3/4 now add the assembly source, linker script, validated ELF-to-HEX
conversion and a bare-metal simulation suite locally. C, libc and general
data/BSS startup remain future work. The build scripts never install tools.

```bash
VERILATOR=/path/to/verilator-5.040/bin/verilator \
  bash verification/scripts/run_instruction_memory.sh

# Optional RISCV_PREFIX=/path/bin/riscv64-unknown-elf-
VERILATOR=/path/to/verilator-5.040/bin/verilator \
  bash verification/scripts/run_baremetal_program.sh
```

## CF-05.1 code-generation inspection

GCC 10.2.0 can be provided through RISCV_GCC or the standard bare-metal
compiler name. The resolver checks the target and the selected Binutils; it
never installs dependencies. The corpus explores O0/O1/O2, medlow/medany and
three data placements. Unsupported instructions and expected link refusals
remain visible in the reports. No RTL capability is added by this inspection.

```bash
BUILD_ROOT=/tmp/cf05-study bash verification/scripts/run_cf05_inventory.sh
```

Read the [CF-05.1 architecture](docs/architecture/cf05-c-toolchain.md) and
[full ISA matrix](docs/verification/cf05-isa-matrix.md). Actual C execution,
startup and further ISA support require subsequent approved implementation.

## CF-05.2a upper immediates

LUI and AUIPC are implemented locally through the EX ALU and ordinary
forwarding/WB paths, with RV64 sign extension and instruction-local PC.
At that milestone the inventory reported 23 of 52 base forms present; this is not full
RV64I compliance. The CF-05.1 matrix remains a historical baseline.
See [architecture](docs/architecture/cf05-upper-immediates.md),
[implementation](docs/implementation/cf05-upper-immediates.md),
[verification](docs/verification/cf05-upper-immediates.md),
[learning notes](docs/learning/cf05-upper-immediates.md) and
[decisions](docs/decisions/cf05-upper-immediates.md).

```bash
VERILATOR=/path/to/verilator-5.040/bin/verilator \
BUILD_ROOT=/tmp/cf05-upper bash verification/scripts/run_upper_immediates.sh
```

No C startup or .data loading policy is introduced by this feature.

## CF-05.2b immediate ALU operations

SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI and SRAI are implemented locally,
reusing the existing ALU and EX forwarding paths. RV64 shift decoding accepts
shamt 0–63 and rejects reserved prefixes. At that milestone the inventory reported
31 of 52 base forms present; full RV64I compliance and C execution remain future.
The separate teaching datapath retains its historical R/ADDI contract.

```bash
VERILATOR=/path/to/verilator-5.040/bin/verilator \
BUILD_ROOT=/tmp/cf05-immediate bash verification/scripts/run_immediate_alu.sh
```

See [architecture](docs/architecture/cf05-immediate-alu.md),
[implementation](docs/implementation/cf05-immediate-alu.md),
[verification](docs/verification/cf05-immediate-alu.md),
[learning notes](docs/learning/cf05-immediate-alu.md) and
[decisions](docs/decisions/cf05-immediate-alu.md).

## License

This project is licensed under the Apache License 2.0.

## CF-05.2c word operations

The nine RV64 word arithmetic and shift forms are implemented with 32-bit
results sign-extended to 64 bits. At that milestone the inventory reported 40 of 52 base
forms; full RV64I compliance and C execution remain future work. See the
[architecture](docs/architecture/cf05-word-alu.md) and
[verification notes](docs/verification/cf05-word-alu.md).

```bash
VERILATOR=/path/to/verilator-5.040/bin/verilator \
  bash verification/scripts/run_word_alu.sh
```

## CF-05.2d word memory accesses

LW and SW add naturally aligned 32-bit loads and stores; LW sign-extends to
64 bits. The live inventory now reports 42 of 52 base forms. Other memory
sizes, full RV64I compliance and C execution remain future work. See the
[architecture](docs/architecture/cf05-word-memory.md) and
[verification notes](docs/verification/cf05-word-memory.md).

```bash
VERILATOR=/path/to/verilator-5.040/bin/verilator \
  bash verification/scripts/run_word_memory.sh
```
