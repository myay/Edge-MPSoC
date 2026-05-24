// Include the header that defines our concrete AXI types
`include "axi_typedefs.svh"

module cpu_bfm (
		input logic clk_i,
		input logic rst_ni,
		// Using the types defined in the included header
		output	    slv_req_t ext_mst_req_o,
		input	    slv_resp_t ext_mst_resp_i
		);

   // Internal register to drive the output
   slv_req_t  req;  // Using the 4-bit ID type for the CPU Master
   slv_resp_t resp;
   assign ext_mst_req_o = req;

   // Hardcode the Address Read ID to 1
   //assign ext_mst_req_o[0].ar.id = 4'h1;

   // Initialization
   initial begin
      req = '0;
      // Default ready signals for response channels
      req.b_ready = 1'b1; 
      req.r_ready = 1'b1;
      //req.ar.id = 4'h1;
   end

   task automatic axi_write(
			    input logic [TB_ADDR_W-1:0]	addr,
			    input logic [TB_DATA_W-1:0]	data
			    );

      $display("[BFM @ %0t] >>> STARTING WRITE TASK", $time);

      // ------------------------------------------------------------------
      // IDLE PHASE
      // ------------------------------------------------------------------
      req.aw_valid <= 1'b0;
      req.w_valid  <= 1'b0;
      req.b_ready  <= 1'b1;

      @(posedge clk_i);

      // ------------------------------------------------------------------
      // DRIVE PAYLOAD
      // ------------------------------------------------------------------
      req.aw.addr <= addr;
      req.aw.id   <= 4'h3;

      req.w.data  <= data;
      req.w.strb  <= '1;
      req.w.last  <= 1'b1;

      @(posedge clk_i);

      // ------------------------------------------------------------------
      // ASSERT VALID
      // ------------------------------------------------------------------
      req.aw_valid <= 1'b1;
      req.w_valid  <= 1'b1;

      // ------------------------------------------------------------------
      // WAIT FOR AW HANDSHAKE
      // ------------------------------------------------------------------
      while (!(req.aw_valid && ext_mst_resp_i.aw_ready)) begin
	 @(posedge clk_i);
      end

      req.aw_valid <= 1'b0;

      // ------------------------------------------------------------------
      // WAIT FOR W HANDSHAKE
      // ------------------------------------------------------------------
      while (!(req.w_valid && ext_mst_resp_i.w_ready)) begin
	 @(posedge clk_i);
      end

      req.w_valid <= 1'b0;

      $display("[BFM @ %0t] AW/W Handshakes Clear. Waiting for BVALID...", $time);

      // ------------------------------------------------------------------
      // WAIT FOR BRESP
      // ------------------------------------------------------------------
      while (!ext_mst_resp_i.b_valid) begin
	 @(posedge clk_i);
      end

      @(posedge clk_i);

      $display("[BFM @ %0t] B_VALID SEEN. Finishing...", $time);

      // ------------------------------------------------------------------
      // RETURN TO CLEAN IDLE
      // ------------------------------------------------------------------
      req.aw_valid <= 1'b0;
      req.w_valid  <= 1'b0;

      @(posedge clk_i);

   endtask

   // --- AXI Read Task ---
   task automatic axi_read(
			   input logic [TB_ADDR_W-1:0]	addr,
			   output logic [TB_DATA_W-1:0]	data
			   );
      $display("[BFM @ %0t] >>> Starting Read: Addr=%h", $time, addr);
      //req.ar.id    = 4'hA; // Give it a specific ID (like 'A' for Alpha)
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
   endtask // axi_read

   // --- Read All Task (Optimized for 64-bit) ---
   task automatic read_all(
			   input logic [31:0] start_addr, // Addr width 32
			   input int	      num_words   // How many 64-bit words to read
			   );
      logic [63:0]			      temp_data;          // Data width 64
      logic [31:0]			      current_addr;

      $display("[BFM @ %0t] === STARTING 64-BIT SRAM DUMP ===", $time);

      for (int i = 0; i < num_words; i++) begin
         // Increment by 8 bytes per 64-bit word
         current_addr = start_addr + (i * 8); 
         
         axi_read(current_addr, temp_data);
         
         $display("[BFM @ %0t] Word %0d | Addr: 0x%h | Data: 0x%h_%h", 
                  $time, i, current_addr, temp_data[63:32], temp_data[31:0]);
      end

      $display("[BFM @ %0t] === 64-BIT SRAM DUMP COMPLETE ===", $time);
   endtask

endmodule
