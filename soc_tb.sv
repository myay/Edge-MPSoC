`timescale 1ns/1ps // unit of time for delay / time precision (resolution of the smallest step the sim takes)
`include "../include/axi/typedef.svh"

module soc_tb;

   // ---------------------------
   // Clock / Reset
   // ---------------------------
   logic clk;
   logic rst_n;

   initial clk = 0;
   always #5 clk = ~clk;

   logic [63:0]	read_data; // Variable to store the result

   initial begin
      $dumpfile("dump.fst");
      $dumpvars(0, soc_tb); // Make sure this matches your TB module name
      rst_n = 0;
      #50 rst_n = 1;

      // --- Write Phase ---
      $display("[TB] Starting AXI Write...");
      i_soc.i_cpu_bfm.axi_write(32'h0000_0010, 64'hDEADBEEFCAFEBABE); 
      
      #100; // Small delay between transactions

      // --- Read Phase ---
      $display("[TB] Starting AXI Read...");
      i_soc.i_cpu_bfm.axi_read(32'h0000_0010, read_data);
      
      // Verification
      if (read_data === 64'hDEADBEEFCAFEBABE) begin
         $display("[TB] SUCCESS: Read data matches written data! (%h)", read_data);
      end else begin
         $display("[TB] ERROR: Data mismatch! Expected DEADBEEFCAFEBABE, Got %h", read_data);
      end

      #100;
      
      // Read the first 128 words (64-bit each) of the SRAM
      i_soc.i_cpu_bfm.read_all(32'h0000_0000, 64);
      
      #5000;
      $display("Simulation limit reached. Ending...");
      $finish;
   end
   // ---------------------------
   // AXI Parameters
   // ---------------------------
   localparam int unsigned AXI_ADDR_WIDTH = 32;
   localparam int unsigned AXI_DATA_WIDTH = 64;
   localparam int unsigned AXI_ID_WIDTH   = 4;
   localparam int unsigned AXI_USER_WIDTH = 1;
   localparam int unsigned NUM_BANKS      = 1;

   // ---------------------------
   // Minimal AXI request/response structs
   // ---------------------------
   // Macro automatically generates a set of packed structs
   `AXI_TYPEDEF_ALL(my_axi, 
                    logic [AXI_ADDR_WIDTH-1:0], 
                    logic [AXI_ID_WIDTH-1:0], 
                    logic [AXI_DATA_WIDTH-1:0], 
                    logic [(AXI_DATA_WIDTH/8)-1:0], 
                    logic [AXI_USER_WIDTH-1:0])

   // 3. Create aliases so your instantiation remains clean
   typedef my_axi_req_t  axi_req_t; // contains master to slave signals
   typedef my_axi_resp_t axi_resp_t; // slace to master signals

   // ---------------------------
   // Signals
   // ---------------------------
   axi_req_t  tb_req;
   axi_resp_t tb_resp;

   soc #(
         .SocAddrWidth (AXI_ADDR_WIDTH),
         .SocDataWidth (AXI_DATA_WIDTH),
         .SocIdWidth   (AXI_ID_WIDTH)
         // REMOVED: .axi_req_t, .axi_resp_t, etc.
	 ) i_soc (
		  .clk_i          (clk),
		  .rst_ni         (rst_n),
		  .ext_mst_req_i  (tb_req),
		  .ext_mst_resp_o (tb_resp)
		  );

   // always @(posedge clk) begin
   //    $display("[WIRE_CHECK @ %0t] AWVALID=%b, AWREADY=%b, WVALID=%b, WREADY=%b, RST_N=%b", 
   // 	       $time, tb_req.aw_valid, tb_resp.aw_ready, tb_req.w_valid, tb_resp.w_ready, rst_n);
   // end
endmodule
