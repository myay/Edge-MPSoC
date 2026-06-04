- folder "own_axi_interconnect" needs to be within pulp/axi (repo) folder
- add common_cells_repo into folder pulp/axi

- then all the required files should be there
  
peakrdl:
- write .rdl file
- peakrdl html data_sampler_wrapper_regs.rdl -o ./docs/register_map/
- peakrdl regblock data_sampler_wrapper_regs.rdl -o generated/ --cpuif axi4-lite-flat
