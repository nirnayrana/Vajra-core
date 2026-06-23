# Vajra ⚡

![Status](https://img.shields.io/badge/status-active-green)
![ISA](https://img.shields.io/badge/ISA-RV32IM-blue)
![Focus](https://img.shields.io/badge/Focus-AI--Native%20Computing-orange)

## Open-Source AI-Native Computing Platform

Vajra is an open-source RISC-V based computing platform focused on processor design, AI acceleration, memory systems, SoC integration, and hardware/software co-design.

The project began as a custom RV32IM processor and is evolving into a broader AI-native computing ecosystem capable of supporting TinyML, Edge AI, robotics, autonomous systems, and future high-performance computing research.

---

## Vision

Modern intelligent systems require more than just processors. They require tightly integrated hardware and software stacks optimized for AI workloads.

Vajra explores the complete computing stack:

- RISC-V Processor Architecture
- Domain-Specific AI Accelerators
- Memory Systems
- SoC Design
- Runtime Infrastructure
- System Software
- Hardware/Software Co-Design

Our long-term goal is to build an open computing ecosystem where processors, accelerators, operating systems, and AI runtimes work together to efficiently execute intelligent workloads.

---

## Current Capabilities

### Processor Subsystem

- RV32IM RISC-V Processor
- 5-Stage Pipeline (IF, ID, EX, MEM, WB)
- Hazard Detection Unit
- Data Forwarding Network
- Branch Handling and Pipeline Flush
- Memory-Mapped I/O
- AXI4-Lite Infrastructure

### Software Stack

- Bare-Metal Runtime Environment
- GCC Toolchain Support
- ELF → HEX Deployment Flow
- C Program Execution on Hardware

### Verification

- RTL Simulation
- Functional Verification
- Waveform Analysis
- Hardware Validation Flow

### Accelerator Development

- INT8 Matrix Multiplication Accelerator
- Weight-Stationary Systolic Array Architecture
- Processing Element (PE) Design
- AXI4-Lite Accelerator Integration
- TinyML Workload Exploration

---

## System Architecture

```text
Application
     │
     ▼
Software Stack
(GCC / Runtime)
     │
     ▼
Vajra Processor
(RV32IM)
     │
     ▼
AXI Interconnect
     │
 ┌───┴─────────┐
 ▼             ▼
Memory      Accelerators
System
                │
                ▼
        TinyML / Edge AI
```

---

## Research Areas

### Computer Architecture

- RISC-V Processors
- Pipeline Design
- Memory Hierarchies
- Data-Level Parallelism

### AI Acceleration

- Systolic Arrays
- Matrix Multiplication Engines
- TinyML Accelerators
- Quantized Inference
- Sparsity-Aware Architectures

### ASIC Design

- RTL Design
- Verification
- Logic Synthesis
- Physical Design
- Timing Analysis
- Silicon Implementation

### System Software

- Runtime Systems
- Device Drivers
- Operating Systems
- Accelerator Programming Models

---

## Current Research Focus

### Lightweight AI Acceleration

- INT8 Computation
- Weight-Stationary Dataflow
- Systolic Arrays
- Keyword Spotting Workloads
- TinyML Inference

### Processor–Accelerator Co-Design

- AXI4-Lite Integration
- Memory-Mapped Interfaces
- Runtime Control
- Hardware–Software Interaction

---

## Roadmap

### Phase 1 — Processor Foundation ✅

- RV32IM Core
- Pipeline Execution
- Hazard Handling
- Bare-Metal Software Execution

### Phase 2 — Accelerator Integration 🚧

- Matrix Multiplication Accelerator
- Systolic Arrays
- TinyML Workloads
- Accelerator Runtime Support

### Phase 3 — AI-Native SoC 🔬

- Integrated AI Accelerators
- Shared Memory Systems
- Multi-Accelerator Architectures

### Phase 4 — Full-Stack Platform 🌌

- Operating System
- Compiler Toolchain
- AI Runtime
- Developer SDK

### Phase 5 — Scalable Intelligent Computing 🚀

- Edge AI Systems
- Robotics Platforms
- Autonomous Machines
- HPC Exploration

---

## Repository Structure

```text
src/        RTL source files
tb/         Testbenches
sw/         Bare-metal software
docs/       Architecture documentation
scripts/    Build automation
build/      Generated artifacts
```

---

## Philosophy

Vajra is not just a processor project.

It is an ongoing effort to explore how future intelligent computing systems can be built through open hardware, open software, and hardware/software co-design.

Every processor, accelerator, memory subsystem, runtime component, and software tool developed within Vajra contributes toward a larger objective:

**Building an Open AI-Native Computing Ecosystem.**

---

## Author

**Nirnay Rana**  
B.Tech Electronics & Telecommunication Engineering  
SGSITS Indore

*"From transistors to intelligent systems."*
