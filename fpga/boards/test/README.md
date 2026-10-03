# Edge-MPSoC PPA Evaluation Flow on FPGAs

This contains the preliminary Vivado automated flow for extracting Power, Performance, and Area (PPA) metrics for the Edge-MPSoC framework. It provides a baseline SoC integration (PicoRV32, AXI interconnects, and memory) configured to pass timing at an x MHz clock target. 

This flow is an example. Possible improvements are to improve the clock frequency and optimize the architecture for better PPA results.

To extract PPA results, run:

```bash
cd /soc_development/Edge-MPSoC/fpga/boards/test
./run.sh
```

Once ./run.sh completes successfully, check the files in the build/output/ directory for the PPA reports.