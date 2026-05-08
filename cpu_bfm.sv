// Include the header that defines our concrete AXI types
`include "axi_typedefs.svh"

module cpu_bfm (
		input logic clk_i,
		input logic rst_ni,
		// Using the types defined in the included header
		output	    req_t ext_mst_req_o,
		input	    resp_t ext_mst_resp_i
		);

   // Internal register to drive the output
   req_t req;
   assign ext_mst_req_o = req;

   // Initialization
   initial begin
      req = '0;
      // Default ready signals for response channels
      req.b_ready = 1'b1; 
      req.r_ready = 1'b1;
   end

   task automatic axi_write(
			    input logic [TB_ADDR_W-1:0]	addr,
			    input logic [TB_DATA_W-1:0]	data
			    );
      $display("[BFM @ %0t] >>> STARTING WRITE TASK", $time); // Is this printing??

      @(posedge clk_i);
      req.aw.addr  = addr;
      req.aw_valid = 1'b1;
      req.w.data   = data;
      req.w_valid  = 1'b1;
      req.w.last   = 1'b1;
      req.w.strb   = '1;

      // Loop until BOTH are acknowledged
      while (!(ext_mst_resp_i.aw_ready && ext_mst_resp_i.w_ready)) begin
         @(posedge clk_i);
         if (ext_mst_resp_i.aw_ready) req.aw_valid = 1'b0;
         if (ext_mst_resp_i.w_ready)  req.w_valid  = 1'b0;
      end
      
      req.aw_valid = 1'b0;
      req.w_valid  = 1'b0;

      $display("[BFM @ %0t] AW/W Handshakes Clear. Waiting for BVALID...", $time);

      wait(ext_mst_resp_i.b_valid);
      $display("[BFM @ %0t] B_VALID SEEN. Finishing...", $time);
      
      @(posedge clk_i);
   endtask

   // --- AXI Read Task ---
   task automatic axi_read(
			   input logic [TB_ADDR_W-1:0]	addr,
			   output logic [TB_DATA_W-1:0]	data
			   );
      $display("[BFM @ %0t] >>> Starting Read: Addr=%h", $time, addr);

      @(posedge clk_i);
      req.ar.addr  = addr;
      req.ar_valid = 1'b1;

      wait (ext_mst_resp_i.ar_ready);
      $display("[BFM @ %0t] ARREADY received", $time);

      @(posedge clk_i);
      req.ar_valid = 1'b0;

      wait (ext_mst_resp_i.r_valid);
      data = ext_mst_resp_i.r.data;
      $display("[BFM @ %0t] <<< Read Complete! Data=%h", $time, data);

      @(posedge clk_i);
   endtask

endmodule
