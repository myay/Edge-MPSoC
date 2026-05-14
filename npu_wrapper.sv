module npu_wrapper #(
		     parameter int unsigned NumMasters = 1 // Define how many you want
		     )(
		       input logic clk_i,
		       input logic rst_ni,

		       // AXI Slave (stays as one for config)
		       // input	   req_t slv_req_i,
		       // output	   resp_t slv_req_o,

		       // AXI Masters (Now an ARRAY)
		       output	   req_t [NumMasters-1:0] mst_req_o,
		       input	   resp_t [NumMasters-1:0] mst_req_i
		       );
   // Your DMA and Systolic Array logic goes here
   // use forenchic's dma engine AXI4 to stream and stream to axi4
   // axi_dma_rd.v (The "Feeder"): Give it start address and length (via slave csrs) and it sucks data out of RAM and pushes it to NPU stream, axi stream (output) connects to NPU 
   // axi_dma_wr.v (collector): waits for npu to spit out results, once results are computed it writes it there, axi stream (input) connects to xbar and RAM

   // npu only needs valid/ready handshake
   // npu needs to speak "axi-stream"

   //Since you're using PULP's req_t and resp_t for the rest of the SoC, your next step will be to create a small "glue" section inside your npu_wrapper to connect your struct signals (like mst_req_o[0].ar.addr) to Forencich’s flat port list (like m_axi_araddr).

   //    // Unpacking PULP struct to Forencich ports (Example for Weight Streamer)
   // axi_dma_rd #(
   //     .AXI_DATA_WIDTH(64),
   //     .AXI_ADDR_WIDTH(32)
   // ) i_weight_dma (
   //     .clk            ( clk_i ),
   //     .rst            ( !rst_ni ),
   //     // Control from CSRs
   //     .read_start     ( reg_start_bit ),
   //     .read_addr      ( reg_weight_base_addr ),
   //     .read_len       ( reg_total_bytes ),
   //     // AXI4 Master Port 0 (Weight Path)
   //     .m_axi_araddr   ( mst_req_o[0].ar.addr ),
   //     .m_axi_arvalid  ( mst_req_o[0].ar_valid ),
   //     .m_axi_arready  ( mst_req_i[0].ar_ready ),
   //     .m_axi_rdata    ( mst_req_i[0].r.data ),
   //     .m_axi_rvalid   ( mst_req_i[0].r_valid ),
   //     .m_axi_rready   ( mst_req_o[0].r_ready ),
   //     // Stream to NPU
   //     .m_axis_tdata   ( weight_stream_data ),
   //     .m_axis_tvalid  ( weight_stream_valid ),
   //     .m_axis_tready  ( weight_stream_ready )
   // );

   //-------------------------------------------------------------------------
   // 1. Control Path: AXI -> AXI-Lite -> APB -> Registers
   //-------------------------------------------------------------------------
   // (Assuming you have these intermediate signals and the APB bridge logic)
   // logic [31:0]			   reg_weight_addr, reg_input_addr;
   // logic [19:0]			   reg_transfer_len;
   // logic			   reg_start_trigger; // Pulses high when CPU writes 'Start'

   // //-------------------------------------------------------------------------
   // // 2. Weight DMA Instance (Master 0)
   // //-------------------------------------------------------------------------

   // // only reads
   // axi_dma_rd #(
   // 		.AXI_DATA_WIDTH    ( 64 ), // Match your SRAM width
   // 		.AXI_ADDR_WIDTH    ( 32 ),
   // 		.AXI_ID_WIDTH      ( 1  ), // PULP IDs vary, 1 is safe for single master
   // 		.LEN_WIDTH         ( 20 )
   // 		) i_weight_dma (
   // 				.clk               ( clk_i  ),
   // 				.rst               ( !rst_ni ), // Forencich is active-high

   // 				/* Descriptor Input (Driven by your APB Registers) */
   // 				.s_axis_read_desc_addr  ( reg_weight_addr      ),
   // 				.s_axis_read_desc_len   ( reg_transfer_len     ),
   // 				.s_axis_read_desc_valid ( reg_start_trigger    ),
   // 				.s_axis_read_desc_ready ( /* status monitor */ ),
				
   // 				/* AXI Stream Output (To your Systolic Array) */
   // 				.m_axis_read_data_tdata ( /* connect to NPU weight port */ ),
   // 				.m_axis_read_data_tvalid( /* connect to NPU weight valid*/ ),
   // 				.m_axis_read_data_tready( /* connect to NPU weight ready*/ ),

   // 				/* AXI Master Interface (Mapped to PULP Structs) */
   // 				.m_axi_arid      ( mst_req_o[0].ar.id     ),
   // 				.m_axi_araddr    ( mst_req_o[0].ar.addr   ),
   // 				.m_axi_arlen     ( mst_req_o[0].ar.len    ),
   // 				.m_axi_arsize    ( mst_req_o[0].ar.size   ),
   // 				.m_axi_arburst   ( mst_req_o[0].ar.burst  ),
   // 				.m_axi_arlock    ( mst_req_o[0].ar.lock   ),
   // 				.m_axi_arcache   ( mst_req_o[0].ar.cache  ),
   // 				.m_axi_arprot    ( mst_req_o[0].ar.prot   ),
   // 				.m_axi_arvalid   ( mst_req_o[0].ar_valid  ),
   // 				.m_axi_arready   ( mst_req_i[0].ar_ready  ),

   // 				.m_axi_rid       ( mst_req_i[0].r.id      ),
   // 				.m_axi_rdata     ( mst_req_i[0].r.data    ),
   // 				.m_axi_rresp     ( mst_req_i[0].r.resp    ),
   // 				.m_axi_rlast     ( mst_req_i[0].r.last    ),
   // 				.m_axi_rvalid    ( mst_req_i[0].r_valid   ),
   // 				.m_axi_rready    ( mst_req_o[0].r_ready   ),

   // 				.enable          ( 1'b1 )
   // 				);

   // // Tie off unused channels in the Master struct (DMA RD doesn't use Write)
   // assign mst_req_o[0].aw_valid = 1'b0;
   // assign mst_req_o[0].w_valid  = 1'b0;
   // assign mst_req_o[0].b_ready  = 1'b0;
endmodule
