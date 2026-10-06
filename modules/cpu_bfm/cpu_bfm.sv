// Include the header that defines our concrete AXI types
`include "axi_typedefs.svh"

module cpu_bfm (
		input logic clk_i,
		input logic rst_ni,

		output	    slv_req_t ext_mst_req_o,
		input	    slv_resp_t ext_mst_resp_i
		);

   // =========================================================================
   // INTERNAL REQUEST STRUCT
   // =========================================================================
   //
   // The previous implementation registered req into ext_mst_req_o. That
   // introduced a one-cycle delay when VALID was cleared after a handshake,
   // allowing AWVALID/WVALID to remain high for an extra cycle and causing
   // duplicate handshakes through the XBAR.
   //
   slv_req_t req;

   // =========================================================================
   // AXI OUTPUT CONNECTION
   // =========================================================================
   //
   // Keep a single source of truth for the AXI request signals. Handshake
   // logic updates req directly and the DUT sees those values without an
   // extra clocked copy.
   //
   always_comb begin
      if (!rst_ni)
        ext_mst_req_o = '0;
      else
        ext_mst_req_o = req;
   end

   // =========================================================================
   // INITIALIZATION
   // =========================================================================

   initial begin
      req = '0;

      // Default idle
      req.aw_valid = 1'b0;
      req.w_valid  = 1'b0;
      req.ar_valid = 1'b0;

      // Response channels
      req.b_ready  = 1'b1;
      req.r_ready  = 1'b0;
   end

   // =========================================================================
   // AXI WRITE TASK
   // =========================================================================

   task automatic axi_write (
			     input logic [TB_ADDR_W-1:0] addr,
			     input logic [TB_DATA_W-1:0] data
			     );

      localparam int unsigned				 TIMEOUT_CYCLES = 1000;

      logic						 aw_handshake_done = 1'b0;
      logic						 w_handshake_done  = 1'b0;

      // Set up the request payload
      req.aw.addr  = addr;
      req.aw.id    = 4'h3;
      req.aw.len   = 8'h0;
      req.aw.size  = 3'b011;
      req.aw.burst = 2'b01;

      req.w.data   = data;
      req.w.strb   = '1;
      req.w.last   = 1'b1;

      $display("[%0t] [BFM] WRITE LAUNCH | Addr: 0x%h | Data: 0x%h",
               $time, addr, data);

      // Launch the transaction.
      @(negedge clk_i);
      req.aw_valid <= 1'b1;
      req.w_valid  <= 1'b1;
      req.b_ready  <= 1'b1;

      // AW and W are independent AXI channels. Each VALID is cleared only
      // by its own VALID && READY handshake.
      fork
         // ------------------------------------------------------------------
         // AW Monitor
         // ------------------------------------------------------------------
         begin : aw_monitor
            int unsigned timeout = 0;

            while (!aw_handshake_done) begin
               @(posedge clk_i);
               if (ext_mst_req_o.aw_valid && ext_mst_resp_i.aw_ready) begin
                  aw_handshake_done = 1'b1;
                  req.aw_valid <= 1'b0;
                  $display("[%0t] [BFM] AW Handshake Complete", $time);
               end
               else begin
                  timeout++;
                  if (timeout >= TIMEOUT_CYCLES) begin
                     $fatal(1,
                            "[BFM] TIMEOUT waiting for AW handshake | Addr=0x%h",
                            addr);
                  end
               end
            end
         end

         // ------------------------------------------------------------------
         // W Monitor
         // ------------------------------------------------------------------
         begin : w_monitor
            int unsigned timeout = 0;

            while (!w_handshake_done) begin
               @(posedge clk_i);
               if (ext_mst_req_o.w_valid && ext_mst_resp_i.w_ready) begin
                  w_handshake_done = 1'b1;
                  req.w_valid <= 1'b0;
                  $display("[%0t] [BFM] W Handshake Complete", $time);
               end
               else begin
                  timeout++;

                  // Do NOT terminate WVALID from BVALID. WVALID must stay
                  // asserted until the WVALID && WREADY handshake occurs.
                  if (timeout >= TIMEOUT_CYCLES) begin
                     $fatal(1,
                            "[BFM] TIMEOUT waiting for W handshake | Addr=0x%h",
                            addr);
                  end
               end
            end
         end
      join

      // Wait for the actual B-channel handshake, not merely BVALID.
      begin : b_monitor
         int unsigned timeout = 0;

         while (!(ext_mst_resp_i.b_valid && ext_mst_req_o.b_ready)) begin
            @(posedge clk_i);
            timeout++;

            if (timeout >= TIMEOUT_CYCLES) begin
               $fatal(1,
                      "[BFM] TIMEOUT waiting for B response | Addr=0x%h",
                      addr);
            end
         end

         $display("[%0t] [BFM] WRITE COMPLETE | B_RESP: %b",
                  $time, ext_mst_resp_i.b.resp);
      end

      // Drop BREADY after the response handshake and before the next
      // rising edge.
      @(negedge clk_i);
      req.b_ready <= 1'b0;

   endtask

   // =========================================================================
   // AXI READ TASK
   // =========================================================================

   task automatic axi_read (
			    input logic [TB_ADDR_W-1:0]	 addr,
			    output logic [TB_DATA_W-1:0] data
			    );

      localparam int unsigned				 TIMEOUT_CYCLES = 1000;

      logic						 ar_done = 1'b0;
      logic						 r_done  = 1'b0;

      // Set up request
      req.ar.addr  = addr;
      req.ar.id    = 4'h1;
      req.ar.len   = 8'h0;
      req.ar.size  = 3'b011;
      req.ar.burst = 2'b01;

      data = '0;

      $display("[%0t] [BFM] READ LAUNCH | Addr: 0x%h", $time, addr);

      // Initiate address phase.
      @(negedge clk_i);
      req.ar_valid <= 1'b1;

      // Wait for AR handshake.
      begin : ar_monitor
         int unsigned timeout = 0;

         while (!ar_done) begin
            @(posedge clk_i);
            if (ext_mst_req_o.ar_valid && ext_mst_resp_i.ar_ready) begin
               req.ar_valid <= 1'b0;
               ar_done = 1'b1;
               $display("[%0t] [BFM] AR Handshake Complete", $time);
            end
            else begin
               timeout++;
               if (timeout >= TIMEOUT_CYCLES) begin
                  $fatal(1,
                         "[BFM] TIMEOUT waiting for AR handshake | Addr=0x%h",
                         addr);
               end
            end
         end
      end

      // Be ready for RDATA immediately after AR has handshaken.
      req.r_ready <= 1'b1;

      // Wait for the actual R-channel handshake.
      begin : r_monitor
         int unsigned timeout = 0;

         while (!r_done) begin
            @(posedge clk_i);
            if (ext_mst_resp_i.r_valid && ext_mst_req_o.r_ready) begin
               data   = ext_mst_resp_i.r.data;
               r_done = 1'b1;
               $display("[%0t] [BFM] READ COMPLETE | DATA=0x%h",
                        $time, data);
            end
            else begin
               timeout++;
               if (timeout >= TIMEOUT_CYCLES) begin
                  $fatal(1,
                         "[BFM] TIMEOUT waiting for R response | Addr=0x%h",
                         addr);
               end
            end
         end
      end

      // Cleanup
      @(negedge clk_i);
      req.r_ready <= 1'b0;

   endtask

   // =========================================================================
   // READ ALL
   // =========================================================================

   task automatic read_all (
			    input logic [31:0] start_addr,
			    input int	       num_words
			    );

      logic [63:0]			       temp_data;
      logic [31:0]			       current_addr;

      $display("[BFM @ %0t] === STARTING 64-BIT SRAM DUMP ===",
               $time);

      for (int i = 0; i < num_words; i++) begin
         current_addr = start_addr + (i * 8);

         axi_read(current_addr, temp_data);

         $display("\n [BFM @ %0t] READ | Word %0d | Addr: 0x%h | Data: 0x%h_%08h",
                  $time,
                  i,
                  current_addr,
                  temp_data[63:32],
                  temp_data[31:0]);
      end

      $display("[BFM @ %0t] === 64-BIT SRAM DUMP COMPLETE ===",
               $time);

   endtask

endmodule
