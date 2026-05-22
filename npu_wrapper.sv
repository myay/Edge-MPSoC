`include "axi_typedefs.svh"
import axi_pkg::*;
import npu_wrapper_regs_pkg::*;
// TODOs
// Instead of hardcoding, use params in a certain headerfile (axi_typedefs) or create a soc config file that all modules get the param values from
module npu_wrapper #(
		     parameter int unsigned NumMasters = 1, // Define how many you want
		     parameter		    type axi_req_t = logic, 
		     parameter		    type axi_resp_t = logic
		     )(
		       input logic clk_i,
		       input logic rst_ni,

		       // ====================================================================
		       // 1. CONFIGURATION SLAVE PATH (Receives CPU writes -> Config Registers)
		       // ====================================================================
		       input	   axi_req_t slv_req_i, 
		       output	   axi_resp_t slv_resp_o, 

		       // ====================================================================
		       // 2. DATA MASTER PATH (Drives NPU DMA fetches -> System Memory)
		       // ====================================================================
		       // Removed [NumMasters] array brackets completely
		       output	   axi_req_t mst_req_o, 
		       input	   axi_resp_t mst_resp_i
		       );

   // --- Hardcoded Descriptor for Initial Research Testing ---
   // This allows the RDMA to start fetching data immediately for debugging
   // TODO: put these three values into regfile, writable via APB from the CPU
   // use peakrdl
   //logic [31:0]			   rdma_addr  = 32'h0000_0000; // Matches SRAM start address
   //logic [19:0]			   rdma_len   = 20'd31;       // Represents the number of bytes in for this DMA. Divide this value by 8 to get the number of beats. Usually it is beats (axi beats = arlen+1)
   //logic			   rdma_valid = 1'b0;          // Pulse this testbench to start


   // Hardcode the Address Read ID to 2
   assign mst_req_o.ar.id = 4'h2;

   // get data from sram
   // dma adress
   logic rdma_valid_internal /* verilator public_flat */;
   assign rdma_valid = rdma_valid_internal;
   logic rdma_tready_internal;
   assign rdma_tready = rdma_valid_internal;
   
   initial begin
      forever @(posedge clk_i) begin
         if (debug_rdma_status_valid) begin
            if (debug_rdma_status_error == 4'h0) begin
               $display("[%0t] [RDMA_OK] Transfer with Tag %0h finished successfully.", $time, debug_rdma_status_tag);
            end else begin
               $display("[%0t] [RDMA_ERROR] Transfer Tag %0h failed with Error Code: %0h", 
                        $time, debug_rdma_status_tag, debug_rdma_status_error);
            end
         end
      end
   end

   // ====================================================================
   // REGISTER INTERFACE STRUCTS & WIRES
   // ====================================================================
   // Output tracking struct from PeakRDL block containing your register values
   npu_wrapper_regs_pkg::npu_wrapper_regs__out_t regs_hwif_out;

   // Flattened wire signals for the 32-bit AXI-Lite interface
   logic	s_axil_awready;
   logic	s_axil_wready;
   logic	s_axil_bvalid;
   logic [1:0]	s_axil_bresp;
   logic	s_axil_arready;
   logic	s_axil_rvalid;
   logic [31:0]	s_axil_rdata;
   logic [1:0]	s_axil_rresp;

   // ====================================================================
   // HARDCODED INTERACTIVE SIGNALS -> SHIFTED TO REGFILE 
   // ====================================================================
   // These hook directly into PeakRDL out-struct fields.
   // Modify field names (.value) if your .rdl file uses distinct naming!
   logic [31:0]	rdma_addr; 
   logic [19:0]	rdma_len;   
   logic	rdma_valid; 

   assign rdma_addr  = regs_hwif_out.REG_RDMA_ADDR.value.value;
   assign rdma_len   = regs_hwif_out.REG_RDMA_LEN.value.value;
   assign rdma_valid = regs_hwif_out.REG_RDMA_CTRL.valid.value;
   
   // --- Internal NPU Signals ---
   logic rdma_desc_ready;    // Backpressure from DMA to your config logic
   logic [63:0]	npu_core_data;     // Payload for your BNN/QNN compute
   logic	npu_core_valid;    // High when data is ready for the core
   logic	npu_core_ready;    // Core handshake (Connect to your core's FIFO/input)
   logic [7:0]	npu_core_keep;     // Byte qualifiers (64-bit = 8 bytes)
   logic	npu_core_last;     // End of weight block indicator

   logic [7:0]  debug_rdma_status_tag;   // Captures the tag of the finished transfer
   logic [3:0]	debug_rdma_status_error; // 4-bit error code (e.g., 2=Slave Error, 3=Decode Error)
   logic	debug_rdma_status_valid; // Pulses high for one cycle when status is ready

   // RDMA
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
				.s_axis_read_desc_addr     ( rdma_addr       ),
				.s_axis_read_desc_len      ( rdma_len        ),
				.s_axis_read_desc_tag      ( 8'h02          ),
				.s_axis_read_desc_id       ( 8'h02          ), // Your NPU ID
				.s_axis_read_desc_dest     ( 8'h00          ),
				.s_axis_read_desc_user     ( 1'b0           ),
				.s_axis_read_desc_valid    ( rdma_valid      ), // asserted by own logic that the command is valid (set in tb)
				.s_axis_read_desc_ready    ( rdma_desc_ready ), // asserted by DMA to indicate it has room ro queue for new request
				.m_axis_read_desc_status_tag  (debug_rdma_status_tag),
				.m_axis_read_desc_status_error(debug_rdma_status_error),
				.m_axis_read_desc_status_valid(debug_rdma_status_valid),
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

   // ====================================================================
   // INTERMEDIATE AXI-LITE PACKED STRUCTURE MODULE WIRES
   // ====================================================================
   axi_lite_req_t  axil_req;
   axi_lite_resp_t axil_resp;

   // ====================================================================
   // AXI4 TO AXI4-LITE DOWN-CONVERTER BRIDGE
   // ====================================================================
   
   // --- Config Path Down-Converter (AXI4 to AXI4-Lite) ---
   axi_to_axi_lite #(
		     .AxiAddrWidth    ( 32              ),
		     .AxiDataWidth    ( 64              ), // Adjust matching your cluster config
		     .AxiIdWidth      ( 4               ), // Adjust matching your cluster config
		     .AxiUserWidth    ( 1               ), 
		     .AxiMaxWriteTxns ( 2               ), // Safe default baseline
		     .AxiMaxReadTxns  ( 2               ), // Safe default baseline
		     .FullBW          ( 1'b0            ),
		     .FallThrough     ( 1'b1            ),
		     .full_req_t      ( slv_req_t       ), // The packed full-AXI struct type from your project
		     .full_resp_t     ( slv_resp_t      ), // The packed full-AXI struct type from your project
		     .lite_req_t      ( axi_lite_req_t      ), // Your AXI-Lite request struct type
		     .lite_resp_t     ( axi_lite_resp_t     )  // Your AXI-Lite response struct type
		     ) i_config_axi_to_lite (
					     .clk_i           ( clk_i           ),
					     .rst_ni          ( rst_ni          ),
					     .test_i          ( 1'b0            ), // Tie off testmode for normal operation
					     
					     // Slave port: Connects to your wrapper's incoming config bus
					     .slv_req_i       ( slv_req_i       ),
					     .slv_resp_o      ( slv_resp_o      ),
					     
					     // Master port: Connects to our local intermediate struct wires
					     .mst_req_o       ( axil_req        ),
					     .mst_resp_i      ( axil_resp       )
					     );

   // ====================================================================
   // STRUCT UNPACKING MAPPING TO FLATTENED REGFILE INTERFACE
   // ====================================================================
   
   // --- Write Address Channel ---
   assign s_axil_awvalid    = axil_req.aw_valid;
   assign axil_resp.aw_ready = s_axil_awready;
   assign s_axil_awaddr     = axil_req.aw.addr[3:0]; // Sliced to fit 4-bit Reg Map
   assign s_axil_awprot     = axil_req.aw.prot;

   // --- Write Data Channel ---
   assign s_axil_wvalid     = axil_req.w_valid;
   assign axil_resp.w_ready  = s_axil_wready;
   assign s_axil_wdata      = axil_req.w.data[31:0]; // Sliced down to 32-bit register width
   assign s_axil_wstrb      = axil_req.w.strb[3:0];

   // --- Write Response Channel ---
   assign axil_resp.b_valid  = s_axil_bvalid;
   assign s_axil_bready     = axil_req.b_ready;
   assign axil_resp.b.resp   = s_axil_bresp;

   // --- Read Address Channel ---
   assign s_axil_arvalid    = axil_req.ar_valid;
   assign axil_resp.ar_ready = s_axil_arready;
   assign s_axil_araddr     = axil_req.ar.addr[3:0]; // Sliced to fit 4-bit Reg Map
   assign s_axil_arprot     = axil_req.ar.prot;

   // --- Read Data Channel ---
   assign axil_resp.r_valid  = s_axil_rvalid;
   assign s_axil_rready     = axil_req.r_ready;
   assign axil_resp.r.resp   = s_axil_rresp;
   
   // Mirror the 32-bit data to both halves of the 64-bit full AXI read lane
   assign axil_resp.r.data   = {s_axil_rdata, s_axil_rdata};

   // ====================================================================
   // PEAKRDL REGISTER FILE INSTANTIATION
   // ====================================================================
   npu_wrapper_regs i_npu_wrapper_regs (
					.clk             ( clk_i           ),
					.rst             ( !rst_ni         ), // Active-high converter
      
					.s_axil_awready  ( s_axil_awready  ),
					.s_axil_awvalid  ( s_axil_awvalid  ),
					.s_axil_awaddr   ( s_axil_awaddr   ),
					.s_axil_awprot   ( s_axil_awprot   ),
					.s_axil_wready   ( s_axil_wready   ),
					.s_axil_wvalid   ( s_axil_wvalid   ),
					.s_axil_wdata    ( s_axil_wdata    ),
					.s_axil_wstrb    ( s_axil_wstrb    ),
					.s_axil_bready   ( s_axil_bready   ),
					.s_axil_bvalid   ( s_axil_bvalid   ),
					.s_axil_bresp    ( s_axil_bresp    ),
					.s_axil_arready  ( s_axil_arready  ),
					.s_axil_arvalid  ( s_axil_arvalid  ),
					.s_axil_araddr   ( s_axil_araddr   ),
					.s_axil_arprot   ( s_axil_arprot   ),
					.s_axil_rready   ( s_axil_rready   ),
					.s_axil_rvalid   ( s_axil_rvalid   ),
					.s_axil_rdata    ( s_axil_rdata    ),
					.s_axil_rresp    ( s_axil_rresp    ),
      
					.hwif_out        ( regs_hwif_out   )
					);
   // TODO: connect AXI bridge to interface
   // Systolic Array logic goes here
   // use forenchic's dma engine AXI4 to stream and stream to axi4
   // axi_dma_rd.v (The "Feeder"): Give it start address and length (via slave csrs) and it sucks data out of RAM and pushes it to NPU stream, axi stream (output) connects to NPU 
   // axi_dma_wr.v (collector): waits for npu to spit out results, once results are computed it writes it there, axi stream (input) connects to xbar and RAM
endmodule
