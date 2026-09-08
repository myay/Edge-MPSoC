Edge-MPSoC: A RISC-V System-on-Chip (SoC) framework for Edge AI including RTL modules, firmware compilation toolchain, register map generation, and simulation infrastructure.

---

## Directory Overview

* **`app/`**: Contains application source files (`start.s`) and the linker script (`sections.lds`). These are compiled into executable binaries for SRAM.
* **`include/`**: Contains global SystemVerilog header files (e.g., `typedef.svh`).
* **`modules/`**: Contains RTL designs (CPU, interconnects, wrappers, generated registers) and memory models (SRAM).

---

## Prerequisites & Setup

Ensure all required dependencies are placed in the correct path under `pulp/axi`:

1. Copy or link `Edge-MPSoC` inside `pulp/axi/`.
2. Add `common_cells` repository inside `pulp/axi/`.

For convenience of development, the folder structure should look like this:
```text
pulp/axi/
├── Edge-MPSoC/
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

### 2. Convert to Verilog Hex

Convert the ELF binary into Verilog Hex format for `$readmemh` memory initialization:

```bash
riscv64-unknown-elf-objcopy -O verilog firmware.elf firmware.hex
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
