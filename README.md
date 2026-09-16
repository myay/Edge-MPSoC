Edge-MPSoC: A RISC-V System-on-Chip (SoC) framework for Edge AI including RTL modules, firmware compilation toolchain, register map generation, and simulation infrastructure.

---

## Directory Overview

* **`app/`**: Contains application source files (`start.s`) and the linker script (`sections.lds`). These are compiled into executable binaries for SRAM.
* **`include/`**: Contains global SystemVerilog header files (e.g., `typedef.svh`).
* **`modules/`**: Contains RTL designs (CPU, interconnects, wrappers, generated registers) and memory models (SRAM).

---

## Prerequisites & Setup

Ensure the following tools and toolchains are installed on your system:

* [Verilator](https://www.veripool.org/verilator/) – Verilog/SystemVerilog simulator
* [Surfer](https://surfer-project.org/) – Waveform viewer
* [PeakRDL](https://github.com/SystemRDL/PeakRDL) – SystemRDL toolchain for register generation
* [RISC-V GCC Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) – Cross-compiler toolchain for RISC-V target architectures
* [liblz4](https://packages.debian.org/sid/liblz4-dev) Install with ```sudo apt-get install liblz4-dev```

Ensure all required dependencies exist and that `common_cells` is located inside `axi`:

1. Clone `Edge-MPSoC`.
2. Clone the [axi](https://github.com/pulp-platform/axi) platform repository.
3. Update `PULP_AXI_PATH` in `run_soc_tb.sh` to reflect the location of `axi/`.
4. Clone the [common_cells](https://github.com/pulp-platform/common_cells) repository inside `axi/`.
5. Update the location of data and exec SRAM init files (.Initfile) in `modules/soc_top/soc.sv` (firmware compilation steps are below and for the data ram init file run `gen_mem.sh 1024` in `modules/sram_node`.

For convenience, structure your directories as follows:

```text
Edge-MPSoC/
axi/
└── common_cells/
```
---

## Register Map Generation (PeakRDL)

Use PeakRDL to generate register documentation and AXI4-Lite regblock RTL from SystemRDL specifications:

```bash
# Generate HTML documentation
peakrdl html data_sampler_wrapper_regs.rdl -o ./docs/register_map/

# Generate AXI4-Lite register block RTL
peakrdl regblock data_sampler_wrapper_regs.rdl -o generated/ --cpuif axi4-lite-flat
```

---

## Firmware Compilation

### 1. Assemble & Link ELF

Compile `start.s` into a RISC-V ELF binary using `sections.lds`:

* **With Standard Libraries:**
  ```bash
  riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -ffreestanding -nostartfiles -T sections.lds start.s -o firmware.elf
  ```

* **Without Standard Libraries:**
  ```bash
  riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -ffreestanding -nostartfiles -nostdlib -T sections.lds start.s -o firmware.elf
  ```
  
* **Or Compile C file directly to hex:**
  ```bash
  riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -Wl,-T,sections.lds start.s main.c -o firmware.elf
  ```

### 2. Convert to Verilog Hex

Convert the ELF binary into Verilog Hex format for `$readmemh` memory initialization:

```bash
riscv64-unknown-elf-objcopy -O verilog --verilog-data-width=8 firmware.elf firmware.hex
```

### 3. Disassemble & Inspect ELF

Inspect disassembly and machine code contents:

```bash
riscv64-unknown-elf-objdump -d firmware.elf
```

---

## Running Simulation

Execute the SoC testbench runner script:

```bash
# Run simulation (without waveform output)
./run_soc_tb.sh

# Run simulation with waveforms (launches Surfer viewer)
./run_soc_tb.sh wf
```

---

TODOs:
- picorv32 integration test
- axi_spi_slave integration test
- cpu (picorv32) bootup test with sanity checks
- improve c-to-hex flow
- set up nightly regression
- FPGA prototyping
- UART integration and printing output of UART pin in Verilator simulation to a terminal in real time