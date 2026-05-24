// =========================================================================
// Module: npu_wrapper.sv
// Description: Neural Processing Accelerator Co-Processor wrapper.
//              Decoupled interface type parameters eliminate structural width 
//              mismatches caused by XBAR master-side transaction ID expansion.
// =========================================================================

`include "axi_typedefs.svh"
import axi_pkg::*;
import npu_wrapper_regs_pkg::*;

module npu_wrapper #(
		     parameter int unsigned NumMasters = 1, 
		     parameter		    type axi_cfg_req_t = logic, 
		     parameter		    type axi_cfg_resp_t = logic,
		     parameter		    type axi_data_req_t = logic,
		     parameter		    type axi_data_resp_t = logic
		     ) (
			input logic clk_i,
			input logic rst_ni,

			// ====================================================================
			// 1. CONFIGURATION SLAVE PATH (Receives CPU writes -> Config Registers)
			// ====================================================================
			input	    axi_cfg_req_t slv_req_i, 
			output	    axi_cfg_resp_t slv_resp_o, 

			// ====================================================================
			// 2. DATA MASTER PATH (Drives NPU DMA fetches -> System Memory)
			// ====================================================================
			output	    axi_data_req_t mst_req_o, 
			input	    axi_data_resp_t mst_resp_i
			);

   // --- Hardcode the Address Read ID to 2 ---
   //assign mst_req_o.ar.id = 4'h2;
   assign npu_core_ready = 1'b1;
   // --- Debug/Simulation Monitors ---
   
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
   // REGISTER INTERFACE STRUCTS & EXPLICIT WIRES
   // ====================================================================
   // Output tracking struct from PeakRDL block containing register values
   npu_wrapper_regs_pkg::npu_wrapper_regs__out_t regs_hwif_out;

   // From Register Block (Outputs)
   logic        s_axil_awready;
   logic	s_axil_wready;
   logic	s_axil_bvalid;
   logic [1:0]	s_axil_bresp;
   logic	s_axil_arready;
   logic	s_axil_rvalid;
   logic [31:0]	s_axil_rdata;
   logic [1:0]	s_axil_rresp;

   // To Register Block (Inputs) - Explicitly declared to prevent 1-bit truncation
   logic	s_axil_awvalid;
   logic [31:0]	s_axil_awaddr;
   logic [2:0]	s_axil_awprot;
   logic	s_axil_wvalid;
   logic [31:0]	s_axil_wdata;
   logic [3:0]	s_axil_wstrb;
   logic	s_axil_bready;
   logic	s_axil_arvalid;
   logic [31:0]	s_axil_araddr;
   logic [2:0]	s_axil_arprot;
   logic	s_axil_rready;

   // ====================================================================
   // REGFILE TO SUBMODULE ROUTING
   // ====================================================================
   logic [31:0]	rdma_addr; 
   logic [19:0]	rdma_len;   
   logic	rdma_valid; 

   assign rdma_addr  = regs_hwif_out.REG_RDMA_ADDR.value.value;
   assign rdma_len   = regs_hwif_out.REG_RDMA_LEN.value.value;
   assign rdma_valid = regs_hwif_out.REG_RDMA_CTRL.valid.value;
   
   // --- Internal NPU Signals ---
   logic	rdma_desc_ready;    
   logic [63:0]	npu_core_data;     
   logic	npu_core_valid;    
   logic	npu_core_ready;    
   logic [7:0]	npu_core_keep;     
   logic	npu_core_last;     

   logic [7:0]	debug_rdma_status_tag;   
   logic [3:0]	debug_rdma_status_error; 
   logic	debug_rdma_status_valid; 

   // ====================================================================
   // AXI READ DMA INSTANTIATION
   // ====================================================================
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
				.clk                           ( clk_i   ),
				.rst                           ( !rst_ni ), 

				/* AXI read descriptor input */
				.s_axis_read_desc_addr         ( rdma_addr        ),
				.s_axis_read_desc_len          ( rdma_len         ),
				.s_axis_read_desc_tag          ( 8'h02            ),
				.s_axis_read_desc_id           ( 8'h02            ), 
				.s_axis_read_desc_dest         ( 8'h00            ),
				.s_axis_read_desc_user         ( 1'b0             ),
				.s_axis_read_desc_valid        ( rdma_valid       ), 
				.s_axis_read_desc_ready        ( rdma_desc_ready  ), 
				.m_axis_read_desc_status_tag   ( debug_rdma_status_tag   ),
				.m_axis_read_desc_status_error ( debug_rdma_status_error ),
				.m_axis_read_desc_status_valid ( debug_rdma_status_valid ),

				/* AXI stream read data output */
				.m_axis_read_data_tdata        ( npu_core_data  ), 
				.m_axis_read_data_tvalid       ( npu_core_valid ), 
				.m_axis_read_data_tready       ( npu_core_ready ), 
				.m_axis_read_data_tkeep        ( npu_core_keep  ),
				.m_axis_read_data_tlast        ( npu_core_last  ),
				.m_axis_read_data_tid          ( ),                
				.m_axis_read_data_tdest        ( ),                
				.m_axis_read_data_tuser        ( ),                

				// --- Read Address Channel (Out) ---
				.m_axi_arid                    ( mst_req_o.ar.id      ), 
				.m_axi_araddr                  ( mst_req_o.ar.addr    ),
				.m_axi_arlen                   ( mst_req_o.ar.len     ),
				.m_axi_arsize                  ( mst_req_o.ar.size    ),
				.m_axi_arburst                 ( mst_req_o.ar.burst   ),
				.m_axi_arlock                  ( mst_req_o.ar.lock    ),
				.m_axi_arcache                 ( mst_req_o.ar.cache   ),
				.m_axi_arprot                  ( mst_req_o.ar.prot    ),
				.m_axi_arvalid                 ( mst_req_o.ar_valid   ), 
				.m_axi_arready                 ( mst_resp_i.ar_ready  ), 

				// --- Read Data Channel (In) ---
				.m_axi_rid                     ( mst_resp_i.r.id      ), 
				.m_axi_rdata                   ( mst_resp_i.r.data    ), 
				.m_axi_rresp                   ( mst_resp_i.r.resp    ),
				.m_axi_rlast                   ( mst_resp_i.r.last    ),
				.m_axi_rvalid                  ( mst_resp_i.r_valid   ), 
				.m_axi_rready                  ( mst_req_o.r_ready    ), 

				.enable                        ( 1'b1                 )
				);

   // --- Structural Tie-offs ---
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
   axi_to_axi_lite #(
		     .AxiAddrWidth    ( 32              ),
		     .AxiDataWidth    ( 64              ), 
		     .AxiIdWidth      ( 4               ), 
		     .AxiUserWidth    ( 1               ), 
		     .AxiMaxWriteTxns ( 2               ), 
		     .AxiMaxReadTxns  ( 2               ), 
		     .FullBW          ( 1'b0            ),
		     .FallThrough     ( 1'b1            ),
		     .full_req_t      ( axi_cfg_req_t   ), // FIXED: Now references configuration slave type parameters
		     .full_resp_t     ( axi_cfg_resp_t  ), // FIXED: Now references configuration slave type parameters
		     .lite_req_t      ( axi_lite_req_t  ), 
		     .lite_resp_t     ( axi_lite_resp_t )  
		     ) i_config_axi_to_lite (
					     .clk_i           ( clk_i           ),
					     .rst_ni          ( rst_ni          ),
					     .test_i          ( 1'b0            ), 
					     
					     .slv_req_i       ( slv_req_i       ),
					     .slv_resp_o      ( slv_resp_o      ),
					     
					     .mst_req_o       ( axil_req        ),
					     .mst_resp_i      ( axil_resp       )
					     );

   // ====================================================================
   // STRUCT UNPACKING MAPPING TO FLATTENED REGFILE INTERFACE
   // ====================================================================
   
   // --- Write Address Channel ---
   assign s_axil_awvalid     = axil_req.aw_valid;
   assign axil_resp.aw_ready = s_axil_awready;
   assign s_axil_awaddr      = {28'h0, axil_req.aw.addr[3:0]};  // TODO correct bitslideing here
   assign s_axil_awprot      = axil_req.aw.prot;

   // --- Write Data Channel ---
   assign s_axil_wvalid      = axil_req.w_valid;
   assign axil_resp.w_ready  = s_axil_wready;
   assign s_axil_wdata       = axil_req.w.data[31:0]; 
   assign s_axil_wstrb       = axil_req.w.strb[3:0];

   // --- Write Response Channel ---
   assign axil_resp.b_valid  = s_axil_bvalid;
   assign s_axil_bready      = axil_req.b_ready;
   assign axil_resp.b.resp   = s_axil_bresp;

   // --- Read Address Channel ---
   assign s_axil_arvalid     = axil_req.ar_valid;
   assign axil_resp.ar_ready = s_axil_arready;
   assign s_axil_araddr      = {28'h0, axil_req.ar.addr[3:0]}; 
   assign s_axil_arprot      = axil_req.ar.prot;

   // --- Read Data Channel ---
   assign axil_resp.r_valid  = s_axil_rvalid;
   assign s_axil_rready      = axil_req.r_ready;
   assign axil_resp.r.resp   = s_axil_rresp;
   
   assign axil_resp.r.data   = {s_axil_rdata, s_axil_rdata};

   // ====================================================================
   // PEAKRDL REGISTER FILE INSTANTIATION
   // ====================================================================
   npu_wrapper_regs i_npu_wrapper_regs (
					.clk             ( clk_i           ),
					.rst             ( !rst_ni         ), 
      
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

   always @(posedge clk_i) begin
      if (rdma_valid && rdma_desc_ready)
	$display("[%0t] DMA DESC ACCEPTED", $time);
   end

endmodule
