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

      logic						aw_done;
      logic						w_done;

      slv_aw_chan_t aw_temp;
      slv_w_chan_t  w_temp;

      aw_done = 1'b0;
      w_done  = 1'b0;

      aw_temp = '0;
      w_temp  = '0;

      // ---------------------------------------------------------------------
      // Prepare AW
      // ---------------------------------------------------------------------

      aw_temp.addr  = addr;
      aw_temp.id    = 4'h3;
      aw_temp.len   = 8'h00;
      aw_temp.size  = 3'b011;
      aw_temp.burst = 2'b01;

      // ---------------------------------------------------------------------
      // Prepare W
      // ---------------------------------------------------------------------

      w_temp.data   = data;
      w_temp.strb   = '1;
      w_temp.last   = 1'b1;

      $display("\n[%0t] [BFM] WRITE LAUNCH | Addr: 0x%h | Data: 0x%h_%08h",
               $time, addr, data[63:32], data[31:0]);

      // ---------------------------------------------------------------------
      // Launch transaction
      // ---------------------------------------------------------------------

      @(negedge clk_i);

      req.aw       <= aw_temp;
      req.aw_valid <= 1'b1;

      req.w        <= w_temp;
      req.w_valid  <= 1'b1;

      // ---------------------------------------------------------------------
      // Wait for AW/W handshakes independently
      // ---------------------------------------------------------------------

      while (!aw_done || !w_done) begin

         @(posedge clk_i);

         // --------------------------------------------------------------
         // AW handshake
         // --------------------------------------------------------------

         if (!aw_done &&
             ext_mst_req_o.aw_valid &&
             ext_mst_resp_i.aw_ready) begin

            aw_done = 1'b1;

            $display("[%0t] [BFM] AW Channel Handshake Complete",
                     $time);

            @(negedge clk_i);
            req.aw_valid <= 1'b0;
         end

         // --------------------------------------------------------------
         // W handshake
         // --------------------------------------------------------------

         if (!w_done &&
             ext_mst_req_o.w_valid &&
             ext_mst_resp_i.w_ready) begin

            w_done = 1'b1;

            $display("[%0t] [BFM] W Channel Handshake Complete",
                     $time);

            @(negedge clk_i);
            req.w_valid <= 1'b0;
         end
      end

      // ---------------------------------------------------------------------
      // Wait for B response
      // ---------------------------------------------------------------------

      $display("[%0t] [BFM] Waiting for B_VALID...", $time);

      while (!ext_mst_resp_i.b_valid)
        @(posedge clk_i);

      $display("[%0t] [BFM] WRITE COMPLETE | B_RESP: %b",
               $time,
               ext_mst_resp_i.b.resp);

   endtask

   // =========================================================================
   // AXI READ TASK
   // =========================================================================

   task automatic axi_read(
			   input logic [TB_ADDR_W-1:0]	addr,
			   output logic [TB_DATA_W-1:0]	data
			   );

      @(negedge clk_i);

      req.ar.addr  <= addr;
      req.ar.id    <= 4'h1;
      req.ar.len   <= 8'h00;
      req.ar.size  <= 3'b011;
      req.ar.burst <= 2'b01;

      req.ar_valid <= 1'b1;

      // ---------------------------------------------------------------------
      // Wait for AR handshake
      // ---------------------------------------------------------------------

      while (!(ext_mst_req_o.ar_valid &&
               ext_mst_resp_i.ar_ready))
        @(posedge clk_i);

      $display("[%0t] [BFM] AR Channel Handshake Complete",
               $time);

      @(negedge clk_i);
      req.ar_valid <= 1'b0;

      // ---------------------------------------------------------------------
      // Wait for read data
      // ---------------------------------------------------------------------

      while (!ext_mst_resp_i.r_valid)
        @(posedge clk_i);

      data = ext_mst_resp_i.r.data;

      $display("[%0t] [BFM] READ COMPLETE | DATA=%h",
               $time,
               data);

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
