// ============================================================================
// Module: data_sampler.sv
// Description:
//    Data Sampler Top-Level Wrapper.
//    Converts configuration AXI to AXI-Lite, implements register file,
//    and uses a descriptor skid-buffer to drive the Write DMA (WDMA).
//    Includes an internal Dummy Data Generator for simulation validation.
// ============================================================================

`include "axi_typedefs.svh"

import axi_pkg::*;
import data_sampler_wrapper_regs_pkg::*;

module data_sampler #(
		      parameter int unsigned NumMasters = 1,
		      parameter		     type axi_cfg_req_t = logic,
		      parameter		     type axi_cfg_resp_t = logic,
		      parameter		     type axi_data_req_t = logic,
		      parameter		     type axi_data_resp_t = logic
		      ) (
			 input logic clk_i,
			 input logic rst_ni,

			 // =========================================================================
			 // CONFIGURATION SLAVE PATH (from Interconnect/CPU)
			 // =========================================================================
			 input	     axi_cfg_req_t slv_req_i,
			 output	     axi_cfg_resp_t slv_resp_o,

			 // =========================================================================
			 // DATA MASTER PATH (to Interconnect/RAM)
			 // =========================================================================
			 output	     axi_data_req_t mst_req_o,
			 input	     axi_data_resp_t mst_resp_i
			 );

   // =========================================================================
   // DEBUG STATUS MONITOR
   // =========================================================================

   // 1. Monitor Write DMA Errors
   initial begin
      forever @(posedge clk_i) begin
         if (debug_wdma_status_valid) begin
            if (debug_wdma_status_error != 4'h0) begin
               $display("[%0t] [WDMA_ERROR] err=%0h", $time, debug_wdma_status_error);
            end
         end
      end
   end

   // 2. Monitor Successful Write Bursts
   always @(posedge clk_i) begin
      if (mst_req_o.w_valid && mst_resp_i.w_ready && mst_req_o.w.last) begin
         $display("[%0t] [WDMA_OK] Burst transfer write complete to RAM", $time);
      end
   end

   // =========================================================================
   // REGFILE STRUCTS
   // =========================================================================
   data_sampler_wrapper_regs_pkg::data_sampler_wrapper_regs__out_t regs_hwif_out;
   data_sampler_wrapper_regs_pkg::data_sampler_wrapper_regs__in_t  regs_hwif_in;

   // =========================================================================
   // HARDWARE TO REGISTER MAPPING (hwif_in)
   // =========================================================================
   always_comb begin
      // 1. Status Register: Busy Flag
      regs_hwif_in.REG_WDMA_STATUS.busy.next = desc_valid_q;

      // 2. Status Register: Transfer Complete Flag
      regs_hwif_in.REG_WDMA_STATUS.done.next = debug_wdma_status_valid;
      
      // 3. Error Register: Error Code
      regs_hwif_in.REG_WDMA_ERR.error.next   = wdma_error_q;
   end
   
   // =========================================================================
   // ERROR CAPTURE FLOP
   // =========================================================================
   logic [3:0] wdma_error_q;

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         wdma_error_q <= 4'h0;
      end else begin
         // Clear the error code when a new transfer is launched
         if (wdma_valid) begin
            wdma_error_q <= 4'h0;
         end
         // Catch the error if the DMA status valid fires with a non-zero error
         else if (debug_wdma_status_valid && (debug_wdma_status_error != 4'h0)) begin
            wdma_error_q <= debug_wdma_status_error;
         end
      end
   end 
   
   // =========================================================================
   // AXI-LITE WIRES
   // =========================================================================
   logic        s_axil_awready;
   logic	s_axil_wready;
   logic	s_axil_bvalid;
   logic [1:0]	s_axil_bresp;
   logic	s_axil_arready;
   logic	s_axil_rvalid;
   logic [31:0]	s_axil_rdata;
   logic [1:0]	s_axil_rresp;

   logic	s_axil_awvalid;
   logic [4:0]	s_axil_awaddr; 
   logic [2:0]	s_axil_awprot;
   logic	s_axil_wvalid;
   logic [31:0]	s_axil_wdata;
   logic [3:0]	s_axil_wstrb;
   logic	s_axil_bready;
   logic	s_axil_arvalid;
   logic [4:0]	s_axil_araddr; 
   logic [2:0]	s_axil_arprot;
   logic	s_axil_rready;

   // =========================================================================
   // WDMA CONTROL
   // =========================================================================
   logic [31:0]	wdma_addr;
   logic [19:0]	wdma_len;
   logic	wdma_valid;

   assign wdma_addr  = regs_hwif_out.REG_WDMA_ADDR.value.value;
   assign wdma_len   = regs_hwif_out.REG_WDMA_LEN.value.value;
   assign wdma_valid = regs_hwif_out.REG_WDMA_CTRL.launch.value;

   // =========================================================================
   // DMA DESCRIPTOR SKID BUFFER
   // =========================================================================
   logic [31:0]	desc_addr_q;
   logic [19:0]	desc_len_q;
   logic	desc_valid_q;
   logic	wdma_desc_ready;

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         desc_valid_q <= 1'b0;
         desc_addr_q  <= '0;
         desc_len_q   <= '0;
      end
      else begin
         if (wdma_valid && !desc_valid_q) begin
            desc_valid_q <= 1'b1;
            desc_addr_q  <= wdma_addr;
            desc_len_q   <= wdma_len;

            $display("[%0t] WDMA DESC QUEUED addr=%h len=%0d",
                     $time, wdma_addr, wdma_len);
         end

         if (desc_valid_q && wdma_desc_ready) begin
            desc_valid_q <= 1'b0;

            $display("[%0t] WDMA DESC ACCEPTED BY DMA ENGINE", $time);
         end
      end
   end 

   // =========================================================================
   // DATA SAMPLER STREAM SIGNALS & DUMMY GENERATOR
   // =========================================================================
   logic [63:0] sampler_axis_data;
   logic	sampler_axis_valid;
   logic	sampler_axis_ready;
   logic [7:0]	sampler_axis_keep;
   logic	sampler_axis_last;

   logic [63:0]	dummy_data_q;
   logic [19:0]	beats_remaining_q;
   logic	is_streaming_q;

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         dummy_data_q      <= 64'd2;
         beats_remaining_q <= '0;
         is_streaming_q    <= 1'b0;
      end else begin
         // 1. Initialize stream when DMA acknowledges the descriptor
         if (desc_valid_q && wdma_desc_ready) begin
            if (desc_len_q >= 8) begin // Ensure minimum valid transfer size
               is_streaming_q    <= 1'b1;
               // Convert bytes to 64-bit (8 byte) beats
               beats_remaining_q <= desc_len_q[19:3]; 
               dummy_data_q      <= 64'd2; // Reset counter back to 2
            end
         end
         // 2. Active streaming phase
         else if (is_streaming_q) begin
            if (sampler_axis_valid && sampler_axis_ready) begin
               dummy_data_q <= dummy_data_q + 1;
               
               if (beats_remaining_q == 20'd1) begin
                  is_streaming_q    <= 1'b0; // Terminate burst
                  beats_remaining_q <= '0;
               end else begin
                  beats_remaining_q <= beats_remaining_q - 1;
               end
            end
         end
      end
   end

   assign sampler_axis_data  = dummy_data_q;
   assign sampler_axis_keep  = 8'hFF;
   assign sampler_axis_valid = is_streaming_q;
   assign sampler_axis_last  = (beats_remaining_q == 20'd1) && is_streaming_q;

   // WDMA status monitoring wires
   logic [19:0] debug_wdma_status_len;
   logic [7:0]	debug_wdma_status_tag;
   logic	debug_wdma_status_valid;
   logic [3:0]	debug_wdma_status_error;

   // =========================================================================
   // INTERMEDIATE DMA ROUTING WIRES (Write Paths)
   // =========================================================================
   logic [3:0]	dma_awid;
   logic [31:0]	dma_awaddr;
   logic [7:0]	dma_awlen;
   logic [2:0]	dma_awsize;
   logic [1:0]	dma_awburst;
   logic	dma_awlock;
   logic [3:0]	dma_awcache;
   logic [2:0]	dma_awprot;
   logic	dma_awvalid;

   logic [63:0]	dma_wdata;
   logic [7:0]	dma_wstrb;
   logic	dma_wlast;
   logic	dma_wvalid;
   
   logic	dma_bready;

   // =========================================================================
   // AXI WRITE DMA INSTANTIATION
   // =========================================================================
   axi_dma_wr #(
		.AXI_DATA_WIDTH    ( 64 ),
		.AXI_ADDR_WIDTH    ( 32 ),
		.AXI_ID_WIDTH      ( 4  ),
		.AXIS_DATA_WIDTH   ( 64 ),
		.LEN_WIDTH         ( 20 ),
		.TAG_WIDTH         ( 8  ),
		.ENABLE_SG         ( 0  ),
		.ENABLE_UNALIGNED  ( 0  )
		) i_axi_dma_wr (
				.clk                            ( clk_i ),
				.rst                            ( !rst_ni ),

				// Descriptor Input
				.s_axis_write_desc_addr         ( desc_addr_q ),
				.s_axis_write_desc_len          ( desc_len_q ),
				.s_axis_write_desc_tag          ( 8'h03 ),
				.s_axis_write_desc_valid        ( desc_valid_q ),
				.s_axis_write_desc_ready        ( wdma_desc_ready ),

				// Descriptor Status Output
				.m_axis_write_desc_status_len   ( debug_wdma_status_len ),
				.m_axis_write_desc_status_tag   ( debug_wdma_status_tag ),
				.m_axis_write_desc_status_id    ( ),
				.m_axis_write_desc_status_dest  ( ),
				.m_axis_write_desc_status_user  ( ),
				.m_axis_write_desc_status_error ( debug_wdma_status_error ),
				.m_axis_write_desc_status_valid ( debug_wdma_status_valid ),

				// Stream Input (Sampling Data)
				.s_axis_write_data_tdata        ( sampler_axis_data ),
				.s_axis_write_data_tkeep        ( sampler_axis_keep ),
				.s_axis_write_data_tvalid       ( sampler_axis_valid ),
				.s_axis_write_data_tready       ( sampler_axis_ready ),
				.s_axis_write_data_tlast        ( sampler_axis_last ),
				.s_axis_write_data_tid          ( 8'h00 ),
				.s_axis_write_data_tdest        ( 8'h00 ),
				.s_axis_write_data_tuser        ( 1'b0 ),

				// AXI Master Infrastructure Mapping
				.m_axi_awid                     ( dma_awid ),
				.m_axi_awaddr                   ( dma_awaddr ),
				.m_axi_awlen                    ( dma_awlen ),
				.m_axi_awsize                   ( dma_awsize ),
				.m_axi_awburst                  ( dma_awburst ),
				.m_axi_awlock                   ( dma_awlock ),
				.m_axi_awcache                  ( dma_awcache ),
				.m_axi_awprot                   ( dma_awprot ),
				.m_axi_awvalid                  ( dma_awvalid ),
				.m_axi_awready                  ( mst_resp_i.aw_ready ),

				.m_axi_wdata                    ( dma_wdata ),
				.m_axi_wstrb                    ( dma_wstrb ),
				.m_axi_wlast                    ( dma_wlast ),
				.m_axi_wvalid                   ( dma_wvalid ),
				.m_axi_wready                   ( mst_resp_i.w_ready ),

				.m_axi_bid                      ( mst_resp_i.b.id ),
				.m_axi_bresp                    ( mst_resp_i.b.resp ),
				.m_axi_bvalid                   ( mst_resp_i.b_valid ),
				.m_axi_bready                   ( dma_bready ),

				.enable                         ( 1'b1 ),
				.abort                          ( 1'b0 )
				);

   // =========================================================================
   // AXI MASTER PORT PACKING
   // =========================================================================
   always_comb begin
      mst_req_o = '0;

      // Write Address Channel
      mst_req_o.aw.id     = dma_awid;
      mst_req_o.aw.addr   = dma_awaddr;
      mst_req_o.aw.len    = dma_awlen;
      mst_req_o.aw.size   = dma_awsize;
      mst_req_o.aw.burst  = dma_awburst;
      mst_req_o.aw.lock   = dma_awlock;
      mst_req_o.aw.cache  = dma_awcache;
      mst_req_o.aw.prot   = dma_awprot;
      mst_req_o.aw_valid  = dma_awvalid;

      // Write Data Channel
      mst_req_o.w.data    = dma_wdata;
      mst_req_o.w.strb    = dma_wstrb;
      mst_req_o.w.last    = dma_wlast;
      mst_req_o.w_valid   = dma_wvalid;

      // Write Response Channel
      mst_req_o.b_ready   = dma_bready;
   end

   // =========================================================================
   // AXI-LITE STRUCTS FOR BRIDGE INTERACTION
   // =========================================================================
   axi_lite_req_t  axil_req;
   axi_lite_resp_t axil_resp;

   // =========================================================================
   // AXI4 -> AXI-LITE BRIDGE
   // =========================================================================
   axi_to_axi_lite #(
		     .AxiAddrWidth    ( 32               ),
		     .AxiDataWidth    ( 64               ),
		     .AxiIdWidth      ( 4                ),
		     .AxiUserWidth    ( 1                ),
		     .AxiMaxWriteTxns ( 2                ),
		     .AxiMaxReadTxns  ( 2                ),
		     .FullBW          ( 1'b0             ),
		     .FallThrough     ( 1'b1             ),
		     .full_req_t      ( axi_cfg_req_t    ),
		     .full_resp_t     ( axi_cfg_resp_t ),
		     .lite_req_t      ( axi_lite_req_t  ),
		     .lite_resp_t     ( axi_lite_resp_t )
		     ) i_config_axi_to_lite (
					     .clk_i      ( clk_i   ),
					     .rst_ni     ( rst_ni  ),
					     .test_i     ( 1'b0    ),

					     .slv_req_i  ( slv_req_i  ),
					     .slv_resp_o ( slv_resp_o ),

					     .mst_req_o  ( axil_req   ),
					     .mst_resp_i ( axil_resp  )
					     );

   // =========================================================================
   // AXI-LITE STRUCT UNPACKING TO FLAT SIGNALS (5-bit address variant)
   // =========================================================================
   assign s_axil_awvalid     = axil_req.aw_valid;
   assign axil_resp.aw_ready = s_axil_awready;
   assign s_axil_awaddr      = axil_req.aw.addr[4:0]; 
   assign s_axil_awprot      = axil_req.aw.prot;

   assign s_axil_wvalid      = axil_req.w_valid;
   assign axil_resp.w_ready  = s_axil_wready;
   assign s_axil_wdata       = axil_req.w.data[31:0];
   assign s_axil_wstrb       = axil_req.w.strb[3:0];

   assign axil_resp.b_valid  = s_axil_bvalid;
   assign s_axil_bready      = axil_req.b_ready;
   assign axil_resp.b.resp   = s_axil_bresp;

   assign s_axil_arvalid     = axil_req.ar_valid;
   assign axil_resp.ar_ready = s_axil_arready;
   assign s_axil_araddr      = axil_req.ar.addr[4:0];
   assign s_axil_arprot      = axil_req.ar.prot;

   assign axil_resp.r_valid  = s_axil_rvalid;
   assign s_axil_rready      = axil_req.r_ready;
   assign axil_resp.r.resp   = s_axil_rresp;
   assign axil_resp.r.data   = {s_axil_rdata, s_axil_rdata}; // Mirror 32-bit registers across 64-bit interconnect

   // =========================================================================
   // FLAT REGISTER FILE INSTANTIATION
   // =========================================================================
   data_sampler_wrapper_regs i_data_sampler_wrapper_regs (
							  .clk             ( clk_i          ),
							  .rst             ( !rst_ni        ),

							  .s_axil_awready  ( s_axil_awready ),
							  .s_axil_awvalid  ( s_axil_awvalid ),
							  .s_axil_awaddr   ( s_axil_awaddr  ),
							  .s_axil_awprot   ( s_axil_awprot  ),

							  .s_axil_wready   ( s_axil_wready  ),
							  .s_axil_wvalid   ( s_axil_wvalid  ),
							  .s_axil_wdata    ( s_axil_wdata   ),
							  .s_axil_wstrb    ( s_axil_wstrb   ),

							  .s_axil_bready   ( s_axil_bready  ),
							  .s_axil_bvalid   ( s_axil_bvalid  ),
							  .s_axil_bresp    ( s_axil_bresp   ),

							  .s_axil_arready  ( s_axil_arready ),
							  .s_axil_arvalid  ( s_axil_arvalid ),
							  .s_axil_araddr   ( s_axil_araddr  ),
							  .s_axil_arprot   ( s_axil_arprot  ),

							  .s_axil_rready   ( s_axil_rready  ),
							  .s_axil_rvalid   ( s_axil_rvalid  ),
							  .s_axil_rdata    ( s_axil_rdata   ),
							  .s_axil_rresp    ( s_axil_rresp   ),

							  .hwif_in         ( regs_hwif_in   ),
							  .hwif_out        ( regs_hwif_out  )
							  );

   // =========================================================================
   // CONSOLE DEBUG MONITOR PRINTS
   // =========================================================================
   integer aw_count = 0;
   integer b_count  = 0;

   always @(posedge clk_i) begin
      if (wdma_valid) begin
         $display("[%0t] [REG_UPDATE] WDMA_VALID_PULSE detected from software configuration", $time);
      end

      if (mst_req_o.aw_valid && mst_resp_i.aw_ready) begin
         aw_count <= aw_count + 1;
         $display("[%0t] [AW_HANDSHAKE] Transfer target memory addr=%h len=%0d id=%0d (#%0d)", 
                  $time, mst_req_o.aw.addr, mst_req_o.aw.len, mst_req_o.aw.id, aw_count);
      end

      if (mst_resp_i.b_valid && mst_req_o.b_ready) begin
         b_count <= b_count + 1;
         $display("[%0t] [B_HANDSHAKE] Write execution acknowledgment transaction finished status=%0d (#%0d)", 
                  $time, mst_resp_i.b.resp, b_count);
      end

      if (sampler_axis_valid && sampler_axis_ready) begin
         $display("[%0t] [AXIS_TX] Pipeline Streaming data=%h last=%0d", 
                  $time, sampler_axis_data, sampler_axis_last);
      end
   end

endmodule
