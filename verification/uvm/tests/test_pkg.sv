package test_pkg;
`include "uvm_macros.svh"
import uvm_pkg::*;

// Include components in dependency order
`include "my_env.sv"
`include "base_test.sv"
endpackage
