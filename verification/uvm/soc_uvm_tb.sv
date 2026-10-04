`include "uvm_macros.svh"
import uvm_pkg::*;
import test_pkg::*; // Import package containing tests and environment

module tb_top;
   bit clk;
   bit rst_n;

   always #5ns clk = ~clk;

   initial begin
      clk = 0;
      rst_n = 0;
      #20ns rst_n = 1;
   end

   initial begin
      run_test("base_test");
   end
endmodule
