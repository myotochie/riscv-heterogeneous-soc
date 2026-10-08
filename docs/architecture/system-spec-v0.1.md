# RISC-V Heterogeneous Multicore SoC

## 1. System Overview

### 1.1 Purpose

This project aims to design, implement, verify, and evaluate a heterogeneous multicore System-on-Chip based on the RISC-V architecture.

The system is intended to demonstrate the complete hardware/software design flow of a modern multicore platform, from processor architecture and memory hierarchy to interconnects, cache coherence, DMA, hardware acceleration, operating-system support, FPGA implementation, and system-level benchmarking.

The project is developed as a personal open-source engineering project and is intended to serve as a practical study platform for computer architecture, digital design, embedded systems, Linux, and heterogeneous computing.

### 1.2 Target System

The target platform shall contain:

* Multiple 64-bit RISC-V processor cores.
* Private L1 instruction and data caches.
* A shared lower-level cache hierarchy.
* A memory-management unit (MMU).
* Translation Lookaside Buffers (TLBs).
* A coherent multicore memory subsystem.
* An interconnect and/or Network-on-Chip (NoC).
* DMA engines for high-throughput data movement.
* AXI-based communication interfaces where appropriate.
* Interrupt and timer infrastructure.
* Boot ROM and system boot software.
* Main memory interface.
* Standard peripheral interfaces required for system bring-up.
* At least one programmable/custom hardware accelerator.
* FPGA implementation.
* Linux SMP support as a final software target.

### 1.3 Design Objectives

The project shall pursue the following objectives:

1. Build a complete multicore RISC-V SoC rather than an isolated CPU core.
2. Understand and implement the interaction between processor cores, caches, memory, interconnects, and peripherals.
3. Explore heterogeneous computing through integration of specialized hardware accelerators.
4. Develop hardware/software co-design skills.
5. Develop a complete verification methodology covering individual IP blocks and the complete SoC.
6. Demonstrate Linux execution on the resulting multicore platform.
7. Measure and analyze system performance using reproducible benchmarks.
8. Implement and validate the architecture on FPGA hardware.

### 1.4 Engineering Constraints

The implementation shall prioritize:

* Correctness before optimization.
* Modular and reusable RTL.
* Clear hardware/software interfaces.
* Reproducible simulation and builds.
* Automated verification wherever practical.
* Explicit architectural decisions and their rationale.
* Measurable performance rather than qualitative claims.
* Incremental integration and validation.

### 1.5 Out of Scope for Version 0.1

The following elements are not yet architecturally frozen:

* Exact number of processor cores.
* Exact cache sizes and associativity.
* Exact cache-coherence protocol.
* Exact NoC topology.
* Exact memory technology/interface.
* Exact RISC-V ISA extensions beyond the required baseline.
* Exact accelerator architecture.
* Final FPGA device.
* Final Linux configuration.

These decisions shall be specified in subsequent revisions of this document after architectural analysis and trade-off studies.
## 2. Architectural Decisions

This section records the initial architectural decisions for Version 0.1 of the system. These decisions define the target architecture and provide a reference for subsequent microarchitectural design, RTL implementation, verification, FPGA integration, and software bring-up.

The decisions are intentionally explicit so that future changes can be evaluated against measurable technical requirements rather than introduced implicitly during implementation.

### 2.1 Processor ISA

**Decision:** RV64GC.

The processor cluster shall implement the 64-bit RISC-V base integer ISA together with the M, A, F, D, and C extensions.

The choice of RV64GC provides an appropriate baseline for a Linux-capable multicore system while maintaining a manageable implementation scope for a custom FPGA-oriented processor.

The A extension is particularly important because atomic memory operations are required for serious multicore software and Linux SMP support. The C extension improves code density, while the F and D extensions provide floating-point support for a broader software workload.

Additional RISC-V extensions shall not be implemented by default. Any future extension shall be introduced only when justified by a specific system requirement or performance study.

### 2.2 Privilege Architecture

**Decision:** Machine (M), Supervisor (S), and User (U) privilege modes.

The processor shall support the M, S, and U privilege levels required to provide a complete software execution environment and to support an operating system such as Linux.

The initial implementation shall prioritize correct privilege transitions, traps, exceptions, interrupts, and CSR behavior before pursuing microarchitectural optimizations.

### 2.3 Virtual Memory

**Decision:** Sv39 virtual-memory mode.

The MMU shall initially implement Sv39, providing 39-bit virtual addresses and a three-level page-table structure.

Each processor core shall contain a TLB for caching recent virtual-to-physical address translations. The implementation shall support the mechanisms required for page-table walking, address translation, protection checks, and page faults.

Sv39 is selected as a practical Linux-capable 64-bit virtual-memory scheme that provides substantial architectural depth without unnecessarily expanding the initial implementation scope.

### 2.4 Number of Processor Cores

**Decision:** Four homogeneous RV64GC cores in the initial multicore cluster.

The system shall contain four processor cores sharing the coherent memory hierarchy.

Four cores provide sufficient architectural complexity to study:

* cache coherence;
* shared-memory communication;
* inter-core synchronization;
* memory contention;
* Linux SMP scheduling; and
* scalability of the interconnect and memory subsystem.

The core count shall remain configurable at the RTL/system-integration level where practical, so that reduced-core configurations can be used for simulation and FPGA bring-up when resource constraints require them.

### 2.5 Processor Microarchitecture

**Decision:** In-order pipeline with an initial target of approximately 5 stages, extensible toward 7 stages if required by timing or microarchitectural studies.

The first implementation shall favor architectural correctness, observability, and verification simplicity over aggressive speculation or out-of-order execution.

Pipeline depth shall therefore be treated as a design parameter rather than a fixed commitment at Version 0.1. Any increase in pipeline depth shall be justified through timing, frequency, or performance analysis.

The initial processor shall include the architectural mechanisms required for:

* instruction fetch and decode;
* integer execution;
* memory operations;
* control-flow instructions;
* CSR access;
* traps and interrupts;
* atomic operations; and
* floating-point operations where required by the selected ISA extensions.

### 2.6 L1 Cache Hierarchy

**Decision:** Private instruction and data L1 caches for every processor core.

Each core shall have:

* one private L1 instruction cache; and
* one private L1 data cache.

The L1 caches shall participate in the system coherence mechanism where required by the memory model and implementation architecture.

Cache size, associativity, line size, replacement policy, and exact timing shall be defined in the detailed microarchitecture specification after the initial workload and FPGA resource analysis.

### 2.7 Shared L2 Cache

**Decision:** Shared L2 cache across the processor cluster.

A shared L2 shall provide a lower-level cache and coherence point for the multicore cluster before accesses reach main memory.

The shared L2 shall be designed with scalability and accelerator/DMA integration in mind. Its exact capacity, associativity, banking, and timing shall be determined during detailed architecture exploration.

### 2.8 Cache Coherence

**Decision:** MESI.

The initial coherent multicore system shall implement the MESI cache-coherence protocol, with the four states:

* Modified;
* Exclusive;
* Shared; and
* Invalid.

MESI is selected as the initial protocol because it provides a sufficiently realistic multicore coherence problem while keeping the first implementation and verification scope manageable.

The implementation shall explicitly address coherence transactions, invalidations, ownership changes, races, ordering constraints, and interaction with the memory consistency requirements of the processor architecture.

MOESI or directory-based optimizations may be investigated in later architectural studies, but they are outside the initial Version 0.1 implementation target.

### 2.9 Interconnect and Network-on-Chip

**Decision:** Incremental interconnect architecture leading to a packet-based NoC.

The system shall not begin with a complex NoC implementation. Development shall proceed in stages.

**Stage 1:** implement and validate a simpler coherent system interconnect suitable for initial CPU, cache, memory, DMA, and peripheral integration.

**Stage 2:** introduce a packet-based NoC to study scalability, communication latency, bandwidth, and contention between processors, memory, DMA engines, and accelerators.

This staged approach allows the project to establish a correct baseline system before introducing NoC-specific complexity.

The NoC topology, routing strategy, flow control, packet format, virtual channels, and arbitration policy shall be defined in a dedicated interconnect/NoC architecture specification.

### 2.10 DMA and Data Movement

**Decision:** AXI4 and AXI4-Stream interfaces for system data movement where appropriate.

DMA engines shall be included to provide high-throughput transfers between memory and hardware components without requiring continuous processor intervention.

AXI4 shall be used for memory-mapped transactions, while AXI4-Stream shall be used where streaming data paths are appropriate, particularly for accelerator integration and FPGA-oriented dataflow processing.

The DMA architecture shall later be evaluated for:

* burst efficiency;
* interrupt behavior;
* scatter/gather support;
* memory consistency;
* cache interaction; and
* achievable bandwidth.

### 2.11 Main Memory

**Decision:** DDR4 as the initial FPGA-oriented target memory technology, with an abstract memory model used during early simulation.

The architectural memory interface shall be separated from the physical FPGA memory controller so that processor and subsystem verification can begin before complete FPGA integration.

The detailed DDR controller and FPGA-specific implementation shall therefore be treated as platform-dependent components rather than fundamental processor functionality.

### 2.12 Interrupt and Timer Infrastructure

**Decision:** RISC-V compatible interrupt and timer infrastructure, with a PLIC-class external interrupt controller and a platform timer mechanism suitable for Linux bring-up.

The interrupt subsystem shall support routing external interrupts to the appropriate processor contexts and shall provide the timer functionality required by the operating system.

The exact implementation mapping between CLINT-style functionality and newer ACLINT-compatible structures shall be resolved during the Linux platform-integration phase based on software compatibility requirements.

### 2.13 Boot and Software Architecture

The system shall provide a boot path progressing from hardware reset to firmware and ultimately to Linux SMP.

The intended software progression is:

1. reset and boot ROM;
2. minimal machine-mode firmware;
3. memory and peripheral initialization;
4. supervisor-mode transition;
5. multicore bring-up;
6. Linux boot; and
7. Linux SMP operation.

Software shall initially be developed and tested in simulation before FPGA deployment.

### 2.14 Hardware Accelerator

**Decision:** Integrate at least one custom hardware accelerator into the heterogeneous SoC.

The accelerator shall be selected based on a workload that exposes meaningful hardware/software partitioning and data-movement trade-offs.

The accelerator shall be evaluated against a software implementation using measurable metrics such as:

* execution latency;
* throughput;
* memory traffic;
* processor utilization; and
* FPGA resource utilization.

The accelerator interface shall be designed so that the project can later serve as a foundation for the dedicated high-performance FPGA accelerator project.

### 2.15 FPGA Target

**Decision:** Begin FPGA implementation with a resource-conscious Zynq-7000-class platform, using a more capable FPGA platform later if the architecture requires additional resources.

The initial FPGA target is intended to provide a practical bring-up and validation environment rather than to represent the final performance target of the architecture.

Simulation shall remain the primary environment for early architectural development, while FPGA implementation shall be introduced progressively as subsystem stability increases.

### 2.16 Verification Strategy

**Decision:** Layered verification using SystemVerilog assertions, Verilator, cocotb, directed tests, and reference models.

Verification shall be performed at multiple levels:

1. unit-level verification of individual RTL blocks;
2. subsystem verification;
3. processor architectural compliance testing;
4. cache and coherence verification;
5. memory-system verification;
6. SoC integration testing;
7. software/firmware bring-up; and
8. FPGA hardware validation.

Verilator shall be used for fast cycle-based simulation where appropriate. cocotb shall provide Python-based testbench infrastructure, while SystemVerilog assertions shall be used to capture important temporal and protocol properties.

Reference platforms such as QEMU and, where useful, Spike shall be used to compare architectural behavior against an established RISC-V execution environment.

### 2.17 Performance Evaluation

Performance evaluation shall be quantitative and reproducible.

The project shall measure, where applicable:

* clock frequency;
* CPI and IPC;
* cache hit/miss behavior;
* memory latency;
* memory bandwidth;
* interconnect and NoC latency;
* DMA throughput;
* accelerator speedup;
* processor utilization; and
* FPGA resource utilization.

Benchmark methodology, workload selection, system configuration, and measurement conditions shall be documented so that results can be reproduced.

### 2.18 Architectural Decision Principles

The following principles govern future architectural decisions:

1. **Correctness before optimization.**
2. **Measure before claiming improvement.**
3. **Prefer modular interfaces and reusable RTL.**
4. **Separate architectural requirements from implementation-specific details.**
5. **Validate each subsystem before integration.**
6. **Keep simulation and FPGA builds reproducible.**
7. **Document significant design decisions and their rationale.**
8. **Avoid unnecessary complexity that does not provide measurable technical value.**
9. **Maintain a clear hardware/software contract at every interface.**
10. **Revisit architectural decisions when benchmark or verification evidence justifies a change.**
