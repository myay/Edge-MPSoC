- folder "own_axi_interconnect" needs to be within pulp/axi (repo) folder
- add common_cells_repo into folder pulp/axi

- then all the required files should be there
  
peakrdl:
- write .rdl file
- peakrdl html data_sampler_wrapper_regs.rdl -o ./docs/register_map/
- peakrdl regblock data_sampler_wrapper_regs.rdl -o generated/ --cpuif axi4-lite-flat


Start CPU
Compile: Assemble the code into an ELF object.
// with stdlibs
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -ffreestanding -nostartfiles -T sections.lds start.s -o firmware.elf

// without stdlibs
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -ffreestanding -nostartfiles -nostdlib -T sections.lds start.s -o firmware.elf

Convert to Verilog Hex: This specific format creates the text file that $readmemh loves.
riscv64-unknown-elf-objcopy -O verilog firmware.elf firmware.hex

see elf content
riscv64-unknown-elf-objdump -d firmware.elf