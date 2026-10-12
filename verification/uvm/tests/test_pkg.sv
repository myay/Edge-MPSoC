package test_pkg;
import uvm_pkg::*;
`include "uvm_macros.svh"
`include "axi_typedefs.svh"
// This package uses preprocessor `include statements to group all dynamic components into a single package scope
   
// Transaction
`include "axi_transaction.sv"

// AXI agent
`include "axi_driver.sv"
`include "axi_monitor.sv"
`include "axi_sequencer.sv"   
`include "axi_agent.sv"
`include "soc_write_read_seq.sv"

// Scoreboard and environment
`include "axi_scoreboard.sv"
`include "soc_env.sv"
   
// Tests
`include "base_test.sv"
`include "soc_sram_read_write_test.sv"
endpackage
