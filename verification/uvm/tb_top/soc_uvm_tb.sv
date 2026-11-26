`include "uvm_macros.svh"
import uvm_pkg::*;
import test_pkg::*; // Import package containing tests and environment

module soc_uvm_tb;
   // ---------------------------
   // Clock & Reset Generation
   // ---------------------------
   logic clk;
   logic rst_n_spi;

   initial clk = 0;
   always #5 clk = ~clk;

   initial begin
      rst_n_spi = 1'b0;
      repeat (10) @(posedge clk);
      rst_n_spi = 1'b1;
   end

   // ---------------------------
   // Waveform Dumping
   // ---------------------------
   initial begin
      $dumpfile("dump.fst");
      $dumpvars(0, tb_top);
   end

   // ---------------------------
   // SPI Test Signals
   // ---------------------------
   logic test_mode = 1'b0;
   logic spi_sclk  = 1'b0;
   logic spi_cs    = 1'b1;
   logic [1:0] spi_mode;
   logic       spi_sdi0 = 1'b0, spi_sdi1 = 1'b0, spi_sdi2 = 1'b0, spi_sdi3 = 1'b0;
   logic       spi_sdo0, spi_sdo1, spi_sdo2, spi_sdo3;


   // Instantiate the interface, binding it to the BFM's request/response structs
   cpu_bfm_if bfm_vif (
		       .clk          (clk),
		       .rst_n        (rst_n),
		       .ext_mst_req  (i_soc.i_cpu_bfm.ext_mst_req_o),
		       .ext_mst_resp (i_soc.i_cpu_bfm.ext_mst_resp_i)
		       );
   // ---------------------------
   // DUT Instantiation
   // ---------------------------
   soc #(
	 .SocAddrWidth ( 32 ),
	 .SocDataWidth ( 64 ),
	 .SocIdWidth   ( 4  )
	 ) i_soc (
		  .clk_i       ( clk       ),
		  .rst_ni      ( rst_n_spi ),

		  .test_mode_i ( test_mode ),
		  .spi_sclk_i  ( spi_sclk  ),
		  .spi_cs_i    ( spi_cs    ),
		  .spi_mode_o  ( spi_mode  ),
		  .spi_sdi0_i  ( spi_sdi0  ),
		  .spi_sdi1_i  ( spi_sdi1  ),
		  .spi_sdi2_i  ( spi_sdi2  ),
		  .spi_sdi3_i  ( spi_sdi3  ),
		  .spi_sdo0_o  ( spi_sdo0  ),
		  .spi_sdo1_o  ( spi_sdo1  ),
		  .spi_sdo2_o  ( spi_sdo2  ),
		  .spi_sdo3_o  ( spi_sdo3  )
		  );

   // ---------------------------
   // UVM Bootstrapper
   // ---------------------------
   initial begin
      // Publish the virtual interface handle to uvm_config_db
      uvm_config_db#(virtual cpu_bfm_if)::set(null, "*", "vif", bfm_vif);

      // Kicks off UVM phase manager (test name can be passed via command line +UVM_TESTNAME=soc_dma_test)
      //run_test("base_test");
      run_test("soc_sram_read_write_test");
   end
endmodule
