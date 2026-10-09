package test_pkg;
`include "uvm_macros.svh"
import uvm_pkg::*;

// This package uses preprocessor `include statements to group all dynamic components into a single package scope
   
// Transaction
`include "axi_transaction.sv"
// Agent
`include "axi_driver.sv"
`include "axi_monitor.sv"
`include "axi_sequencer.sv"   
`include "axi_agent.sv"

// Environment Component and Scoreboard
`include "axi_scoreboard.sv"
`include "my_env.sv"
   
// Tests
`include "base_test.sv"
`include "soc_sram_read_write_test.sv"
endpackage
