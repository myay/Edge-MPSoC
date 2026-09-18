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

   slv_req_t req;

   // =========================================================================
   // REGISTERED AXI OUTPUTS
   // IMPORTANT:
   // Breaks combinational feedback through NO_LATENCY XBAR
   // =========================================================================

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)
        ext_mst_req_o <= '0;
      else
        ext_mst_req_o <= req;
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

      // Always ready for responses
      req.b_ready  = 1'b1;
      req.r_ready  = 1'b1;
   end

   // =========================================================================
   // AXI WRITE TASK
   // =========================================================================
   task automatic axi_write(
			    input logic [TB_ADDR_W-1:0]	addr,
			    input logic [TB_DATA_W-1:0]	data
			    );
      // Local flags to track completion
      logic						aw_handshake_done = 1'b0;
      logic						w_handshake_done  = 1'b0;

      // Set up the request payload
      req.aw.addr  = addr;
      req.aw.id    = 4'h3;
      req.aw.len   = 8'h0;
      req.aw.size  = 3'b011;
      req.aw.burst = 2'b01;

      req.w.data   = data;
      req.w.strb   = '1;
      req.w.last   = 1'b1;

      $display("[%0t] [BFM] WRITE LAUNCH | Addr: 0x%h | Data: 0x%h", $time, addr, data);

      // 1. Launch the transaction
      @(negedge clk_i);
      req.aw_valid <= 1'b1;
      req.w_valid  <= 1'b1;

      // 2. Monitor handshakes in parallel to avoid stalling
      fork
         // AW Monitor
         begin
            while (!aw_handshake_done) begin
               @(posedge clk_i);
               if (ext_mst_req_o.aw_valid && ext_mst_resp_i.aw_ready) begin
                  aw_handshake_done = 1'b1;
                  req.aw_valid <= 1'b0; // Drop immediately
                  $display("[%0t] [BFM] AW Handshake Complete", $time);
               end
            end
         end

         // W Monitor
         begin
            while (!w_handshake_done) begin
               @(posedge clk_i);
               if (ext_mst_req_o.w_valid && ext_mst_resp_i.w_ready) begin
                  w_handshake_done = 1'b1;
                  req.w_valid <= 1'b0; // Drop immediately
                  $display("[%0t] [BFM] W Handshake Complete", $time);
               end
               // SAFETY: If the slave responds with B_VALID, the transaction
               // is effectively over. Stop driving W immediately.
	       // signal from the Slave to the Master that the write transaction has completed and that the response information is currently available on the bus
               if (ext_mst_resp_i.b_valid) begin
                  w_handshake_done = 1'b1;
                  req.w_valid <= 1'b0;
                  $display("[%0t] [BFM] W-Channel auto-stopped by B_VALID", $time);
               end
            end
         end
      join

      // 3. Wait for Write Response (B-Channel)
      req.b_ready <= 1'b1; // Ready to accept response
      
      // Wait for the response to be driven by the slave
      wait(ext_mst_resp_i.b_valid); 
      
      @(posedge clk_i);
      req.b_ready <= 1'b0; // Handshake complete, drop ready
      
      $display("[%0t] [BFM] WRITE COMPLETE | B_RESP: %b", $time, ext_mst_resp_i.b.resp);
   endtask

   // =========================================================================
   // AXI READ TASK
   // =========================================================================

   task automatic axi_read(
			   input logic [TB_ADDR_W-1:0]	addr,
			   output logic [TB_DATA_W-1:0]	data
			   );
      logic						ar_done = 1'b0;
      logic						r_done  = 1'b0;

      // Set up request
      req.ar.addr  = addr;
      req.ar.id    = 4'h1;
      req.ar.len   = 8'h0;
      req.ar.size  = 3'b011;
      req.ar.burst = 2'b01;

      $display("[%0t] [BFM] READ LAUNCH | Addr: 0x%h", $time, addr);
      req.ar_valid <= 1'b1;
      // 1. Initiate Address phase
      @(negedge clk_i);
      req.ar_valid <= 1'b1;

      // 2. Wait for AR handshake
      while (!ar_done) begin
         @(posedge clk_i);
         if (ext_mst_req_o.ar_valid && ext_mst_resp_i.ar_ready) begin
            req.ar_valid <= 1'b0; // CRITICAL: Drop VALID immediately
            ar_done = 1'b1;
            $display("[%0t] [BFM] AR Handshake Complete", $time);
         end
      end

      // 3. Prepare for Data phase
      req.r_ready <= 1'b1;

      // 4. Wait for RDATA
      while (!r_done) begin
         @(posedge clk_i);
         if (ext_mst_resp_i.r_valid && ext_mst_req_o.r_ready) begin
            data    = ext_mst_resp_i.r.data;
            r_done  = 1'b1;
            $display("[%0t] [BFM] READ COMPLETE | DATA=0x%h", $time, data);
         end
      end
      
      // 5. Cleanup
      @(negedge clk_i);
      req.r_ready <= 1'b0;
   endtask

   // =========================================================================
   // READ ALL
   // =========================================================================

   task automatic read_all(
			   input logic [31:0] start_addr,
			   input int	      num_words
			   );

      logic [63:0]			      temp_data;
      logic [31:0]			      current_addr;

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
