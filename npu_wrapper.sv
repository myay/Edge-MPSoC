module npu_wrapper #(
		     parameter int unsigned NumMasters = 1, // Define how many you want
		     parameter		    type axi_req_t = logic, 
		     parameter		    type axi_resp_t = logic
		     )(
		       input logic clk_i,
		       input logic rst_ni,

		       // AXI Slave (stays as one for config)
		       // input	   req_t slv_req_i,
		       // output	   resp_t slv_req_o,

		       // AXI Masters (data path, connects to xbar)
		       // output	   req_t mst_req_o[NumMasters-1:0],
		       // input	   resp_t mst_req_i[NumMasters-1:0]
		       output	   slv_req_t mst_req_o,
		       input	   slv_resp_t mst_resp_i
		       );

   // --- Hardcoded Descriptor for Initial Research Testing ---
   // This allows the DMA to start fetching data immediately for debugging
   logic [31:0]			   dma_addr  = 32'h0000_0000; // Matches SRAM start address
   logic [19:0]			   dma_len   = 20'd31;       // Represents the number of bytes in for this DMA. Divide this value by 8 to get the number of beats. Usually it is beats (axi beats = arlen+1)
   logic			   dma_valid = 1'b0;          // Pulse this testbench to start


   // Hardcode the Address Read ID to 2
   assign mst_req_o.ar.id = 4'h2;

   // get data from sram
   // dma adress
   logic rdma_valid_internal /* verilator public_flat */;
   assign dma_valid = rdma_valid_internal;
   logic rdma_tready_internal;
   assign dma_tready = rdma_valid_internal;
   
   initial begin
      forever @(posedge clk_i) begin
         if (debug_dma_status_valid) begin
            if (debug_dma_status_error == 4'h0) begin
               $display("[%0t] [DMA_OK] Transfer with Tag %0h finished successfully.", $time, debug_dma_status_tag);
            end else begin
               $display("[%0t] [DMA_ERROR] Transfer Tag %0h failed with Error Code: %0h", 
                        $time, debug_dma_status_tag, debug_dma_status_error);
            end
         end
      end
   end

   
   // --- Internal NPU Signals ---
   logic dma_desc_ready;    // Backpressure from DMA to your config logic
   logic [63:0]	npu_core_data;     // Payload for your BNN/QNN compute
   logic	npu_core_valid;    // High when data is ready for the core
   logic	npu_core_ready;    // Core handshake (Connect to your core's FIFO/input)
   logic [7:0]	npu_core_keep;     // Byte qualifiers (64-bit = 8 bytes)
   logic	npu_core_last;     // End of weight block indicator

   logic [7:0]  debug_dma_status_tag;   // Captures the tag of the finished transfer
   logic [3:0]	debug_dma_status_error; // 4-bit error code (e.g., 2=Slave Error, 3=Decode Error)
   logic	debug_dma_status_valid; // Pulses high for one cycle when status is ready
   
   axi_dma_rd #(
		.AXI_DATA_WIDTH    ( 64 ),
		.AXI_ADDR_WIDTH    ( 32 ),
		.AXI_ID_WIDTH      ( 4  ), 
		.AXIS_DATA_WIDTH   ( 64 ),
		.LEN_WIDTH         ( 20 ),
		.TAG_WIDTH         ( 8  ),
		.ENABLE_SG         ( 0  ),
		.ENABLE_UNALIGNED  ( 0  )
		) i_axi_dma_rd (
				.clk                       ( clk_i   ),
				.rst                       ( !rst_ni ), // Forencich DMA uses active-high reset

				/* AXI read descriptor input (Control Path) */
				// control (address to start, how many bytes, id, etc
				.s_axis_read_desc_addr     ( dma_addr       ),
				.s_axis_read_desc_len      ( dma_len        ),
				.s_axis_read_desc_tag      ( 8'h02          ),
				.s_axis_read_desc_id       ( 8'h02          ), // Your NPU ID
				.s_axis_read_desc_dest     ( 8'h00          ),
				.s_axis_read_desc_user     ( 1'b0           ),
				.s_axis_read_desc_valid    ( dma_valid      ), // asserted by own logic that the command is valid (set in tb)
				.s_axis_read_desc_ready    ( dma_desc_ready ), // asserted by DMA to indicate it has room ro queue for new request
				.m_axis_read_desc_status_tag  (debug_dma_status_tag),
				.m_axis_read_desc_status_error(debug_dma_status_error),
				.m_axis_read_desc_status_valid(debug_dma_status_valid),
				/* AXI stream read data output (Data Path to NPU Logic) into NPU */
				.m_axis_read_data_tdata     ( npu_core_data  ), 
				.m_axis_read_data_tvalid    ( npu_core_valid ), // NEEDS TO BE HIGH for success
				.m_axis_read_data_tready    ( npu_core_ready ), // Input from NPU core; if pulled low, it pauses the DMA data flow.
				.m_axis_read_data_tkeep     ( npu_core_keep  ),
				.m_axis_read_data_tlast     ( npu_core_last  ),
				.m_axis_read_data_tid       ( ),               // Optional: Unused
				.m_axis_read_data_tdest     ( ),               // Optional: Unused
				.m_axis_read_data_tuser     ( ),               // Optional: Unused

				// --- Read Address Channel (Out) ---
				.m_axi_arid      ( mst_req_o.ar.id      ), 
				.m_axi_araddr    ( mst_req_o.ar.addr    ),
				.m_axi_arlen     ( mst_req_o.ar.len     ),
				.m_axi_arsize    ( mst_req_o.ar.size    ),
				.m_axi_arburst   ( mst_req_o.ar.burst   ),
				.m_axi_arlock    ( mst_req_o.ar.lock    ),
				.m_axi_arcache   ( mst_req_o.ar.cache   ),
				.m_axi_arprot    ( mst_req_o.ar.prot    ),
				.m_axi_arvalid   ( mst_req_o.ar_valid   ), // Flattened in slv_req_t
				.m_axi_arready   ( mst_resp_i.ar_ready  ), // From slv_resp_t (Input)

				// --- Read Data Channel (In) ---
				.m_axi_rid       ( mst_resp_i.r.id      ), // From slv_resp_t (Input)
				.m_axi_rdata     ( mst_resp_i.r.data    ), 
				.m_axi_rresp     ( mst_resp_i.r.resp    ),
				.m_axi_rlast     ( mst_resp_i.r.last    ),
				.m_axi_rvalid    ( mst_resp_i.r_valid   ), // Flattened in slv_resp_t
				.m_axi_rready    ( mst_req_o.r_ready    ), // Master drives this (Output)

				.enable          ( 1'b1                 )
				);

   // --- Structural Tie-offs ---
   // The Read DMA does not use Write (AW/W) channels
   assign mst_req_o.aw_valid = 1'b0;
   assign mst_req_o.w_valid  = 1'b0;
   assign mst_req_o.b_ready  = 1'b1;

   
   // Systolic Array logic goes here
   // use forenchic's dma engine AXI4 to stream and stream to axi4
   // axi_dma_rd.v (The "Feeder"): Give it start address and length (via slave csrs) and it sucks data out of RAM and pushes it to NPU stream, axi stream (output) connects to NPU 
   // axi_dma_wr.v (collector): waits for npu to spit out results, once results are computed it writes it there, axi stream (input) connects to xbar and RAM
endmodule
