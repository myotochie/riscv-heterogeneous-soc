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

**Current phase:** Architecture and system specification.

The first implementation phase will focus on establishing the processor microarchitecture and a robust RTL/verification foundation before progressively integrating multicore features.

## License

This project is licensed under the Apache License 2.0.

# Test contribution
