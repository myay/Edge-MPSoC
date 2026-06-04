// ============================================================================
// Module: npu_wrapper.sv
// Description:
//   Neural Processing Accelerator Co-Processor wrapper.
//
// FIXED VERSION
//   - Proper descriptor skid-buffer
//   - VALID held until actual VALID&&READY handshake
//   - Prevents lost descriptors due to axi_dma_rd prefetch timing
//   - Handles backpressure correctly
//   - AXIS always ready
//   - Zero-poisoning resolved via structural packing block
// ============================================================================

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

                        // =========================================================================
                        // CONFIGURATION SLAVE PATH
                        // =========================================================================

                        input	    axi_cfg_req_t slv_req_i,
                        output	    axi_cfg_resp_t slv_resp_o,

                        // =========================================================================
                        // DATA MASTER PATH
                        // =========================================================================

                        output	    axi_data_req_t mst_req_o,
                        input	    axi_data_resp_t mst_resp_i
                        );

   // =========================================================================
   // DEBUG STATUS MONITOR
   // =========================================================================

   // 1. Keep this block to monitor ERRORS (Control Plane)
   initial begin
      forever @(posedge clk_i) begin
         if (debug_rdma_status_valid) begin
            if (debug_rdma_status_error != 4'h0) begin
               $display("[%0t] [RDMA_ERROR] err=%0h", $time, debug_rdma_status_error);
            end
         end
      end
   end

   // 2. Add this block to monitor SUCCESS (Data Plane)
   always @(posedge clk_i) begin
      // We look for valid data, ready from downstream, and the TLAST pulse
      if (npu_core_valid && npu_core_ready && npu_core_last_raw) begin
         $display("[%0t] [RDMA_OK] Transfer complete (Data received)", $time);
      end
   end

   // =========================================================================
   // REGFILE STRUCTS
   // =========================================================================

   npu_wrapper_regs_pkg::npu_wrapper_regs__out_t regs_hwif_out;

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

   // =========================================================================
   // RDMA CONTROL
   // =========================================================================

   logic [31:0]	rdma_addr;
   logic [19:0]	rdma_len;

   logic	rdma_valid;

   assign rdma_addr =
                     regs_hwif_out.REG_RDMA_ADDR.value.value;

   assign rdma_len =
                    regs_hwif_out.REG_RDMA_LEN.value.value;

   assign rdma_valid =
                      regs_hwif_out.REG_RDMA_CTRL.valid.value;

   // =========================================================================
   // DMA DESCRIPTOR SKID BUFFER
   // =========================================================================

   logic [31:0]	desc_addr_q;
   logic [19:0]	desc_len_q;

   logic	desc_valid_q;
   logic	rdma_desc_ready;

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin

         desc_valid_q <= 1'b0;
         desc_addr_q  <= '0;
         desc_len_q   <= '0;

      end
      else begin

         if (rdma_valid && !desc_valid_q) begin

            desc_valid_q <= 1'b1;
            desc_addr_q  <= rdma_addr;
            desc_len_q   <= rdma_len;

            $display("[%0t] RDMA DESC QUEUED addr=%h len=%0d",
                     $time,
                     rdma_addr,
                     rdma_len);
         end

         if (desc_valid_q && rdma_desc_ready) begin

            desc_valid_q <= 1'b0;

            $display("[%0t] DMA DESC ACCEPTED",
                     $time);
         end
      end
   end 

   // =========================================================================
   // DMA STREAM SIGNALS
   // =========================================================================

   logic [63:0] npu_core_data;
   logic	npu_core_valid;
   logic	npu_core_ready;
   logic [7:0]	npu_core_keep;
   logic	npu_core_last;

   logic [7:0]	debug_rdma_status_tag;
   logic [3:0]	debug_rdma_status_error;
   logic	debug_rdma_status_valid;

   logic	npu_core_last_raw;

   assign npu_core_last =
			 npu_core_valid &&
			 npu_core_last_raw;

   assign npu_core_ready = 1'b1;

   // =========================================================================
   // INTERMEDIATE DMA ROUTING WIRES
   // =========================================================================

   logic [3:0]	dma_arid;
   logic [31:0]	dma_araddr;
   logic [7:0]	dma_arlen;
   logic [2:0]	dma_arsize;
   logic [1:0]	dma_arburst;
   logic	dma_arlock;
   logic [3:0]	dma_arcache;
   logic [2:0]	dma_arprot;
   logic	dma_arvalid;
   logic	dma_rready;

   // =========================================================================
   // AXI DMA READER
   // =========================================================================

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

                                .s_axis_read_desc_addr         ( desc_addr_q     ),
                                .s_axis_read_desc_len          ( desc_len_q      ),
                                .s_axis_read_desc_tag          ( 8'h02           ),
                                .s_axis_read_desc_id           ( 8'h02           ),
                                .s_axis_read_desc_dest         ( 8'h00           ),
                                .s_axis_read_desc_user         ( 1'b0            ),
                                .s_axis_read_desc_valid        ( desc_valid_q    ),
                                .s_axis_read_desc_ready        ( rdma_desc_ready ),

                                .m_axis_read_desc_status_tag   ( debug_rdma_status_tag   ),
                                .m_axis_read_desc_status_error ( debug_rdma_status_error ),
                                .m_axis_read_desc_status_valid ( debug_rdma_status_valid ),

                                .m_axis_read_data_tdata        ( npu_core_data  ),
                                .m_axis_read_data_tvalid       ( npu_core_valid ),
                                .m_axis_read_data_tready       ( npu_core_ready ),
                                .m_axis_read_data_tkeep        ( npu_core_keep  ),
                                .m_axis_read_data_tlast        ( npu_core_last_raw  ),
                                .m_axis_read_data_tid          ( ),
                                .m_axis_read_data_tdest        ( ),
                                .m_axis_read_data_tuser        ( ),

                                .m_axi_arid                    ( dma_arid      ),
                                .m_axi_araddr                  ( dma_araddr    ),
                                .m_axi_arlen                   ( dma_arlen     ),
                                .m_axi_arsize                  ( dma_arsize    ),
                                .m_axi_arburst                 ( dma_arburst   ),
                                .m_axi_arlock                  ( dma_arlock    ),
                                .m_axi_arcache                 ( dma_arcache   ),
                                .m_axi_arprot                  ( dma_arprot    ),
                                .m_axi_arvalid                 ( dma_arvalid   ),
                                .m_axi_arready                 ( mst_resp_i.ar_ready ),

                                .m_axi_rid                     ( mst_resp_i.r.id     ),
                                .m_axi_rdata                   ( mst_resp_i.r.data   ),
                                .m_axi_rresp                   ( mst_resp_i.r.resp   ),
                                .m_axi_rlast                   ( mst_resp_i.r.last   ),
                                .m_axi_rvalid                  ( mst_resp_i.r_valid  ),
                                .m_axi_rready                  ( dma_rready    ),

                                .enable                        ( 1'b1 )
                                );

   // =========================================================================
   // AXI MASTER PORT PACKING & STRUCTURAL TIEOFFS
   // =========================================================================

   always_comb begin
      mst_req_o = '0;

      mst_req_o.ar.id    = dma_arid;
      mst_req_o.ar.addr  = dma_araddr;
      mst_req_o.ar.len   = dma_arlen;
      mst_req_o.ar.size  = dma_arsize;
      mst_req_o.ar.burst = dma_arburst;
      mst_req_o.ar.lock  = dma_arlock;
      mst_req_o.ar.cache = dma_arcache;
      mst_req_o.ar.prot  = dma_arprot;
      mst_req_o.ar_valid = dma_arvalid;

      mst_req_o.r_ready  = dma_rready;
   end

   // =========================================================================
   // AXI-LITE STRUCTS
   // =========================================================================

   axi_lite_req_t  axil_req;
   axi_lite_resp_t axil_resp;

   // =========================================================================
   // AXI4 -> AXI-LITE BRIDGE
   // =========================================================================

   axi_to_axi_lite #(
                     .AxiAddrWidth    ( 32              ),
                     .AxiDataWidth    ( 64              ),
                     .AxiIdWidth      ( 4               ),
                     .AxiUserWidth    ( 1               ),
                     .AxiMaxWriteTxns ( 2               ),
                     .AxiMaxReadTxns  ( 2               ),
                     .FullBW          ( 1'b0            ),
                     .FallThrough     ( 1'b1            ),
                     .full_req_t      ( axi_cfg_req_t   ),
                     .full_resp_t     ( axi_cfg_resp_t  ),
                     .lite_req_t      ( axi_lite_req_t  ),
                     .lite_resp_t     ( axi_lite_resp_t )
                     ) i_config_axi_to_lite (

                                             .clk_i      ( clk_i      ),
                                             .rst_ni     ( rst_ni     ),
                                             .test_i     ( 1'b0       ),

                                             .slv_req_i  ( slv_req_i  ),
                                             .slv_resp_o ( slv_resp_o ),

                                             .mst_req_o  ( axil_req   ),
                                             .mst_resp_i ( axil_resp  )
                                             );

   // =========================================================================
   // AXI-LITE UNPACKING
   // =========================================================================

   assign s_axil_awvalid     = axil_req.aw_valid;
   assign axil_resp.aw_ready = s_axil_awready;
   assign s_axil_awaddr      = {28'h0, axil_req.aw.addr[3:0]};
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
   assign s_axil_araddr      = {28'h0, axil_req.ar.addr[3:0]};
   assign s_axil_arprot      = axil_req.ar.prot;

   assign axil_resp.r_valid  = s_axil_rvalid;
   assign s_axil_rready      = axil_req.r_ready;
   assign axil_resp.r.resp   = s_axil_rresp;

   assign axil_resp.r.data   = {s_axil_rdata, s_axil_rdata};

   // =========================================================================
   // REGISTER FILE
   // =========================================================================

   npu_wrapper_regs i_npu_wrapper_regs (

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

                                        .hwif_out        ( regs_hwif_out  )
                                        );

   // =========================================================================
   // DEBUG PRINTS
   // =========================================================================
   integer  ar_count;
   integer  r_count;
   always @(posedge clk_i) begin

      if (rdma_valid)
        $display("[%0t] RDMA_VALID_PULSE", $time);

      if (mst_resp_i.r_valid) begin
         $display("[%0t] RVALID=%0d RREADY=%0d RLAST=%0d DATA=%h",
                  $time,
                  mst_resp_i.r_valid,
                  mst_req_o.r_ready,
                  mst_resp_i.r.last,
                  mst_resp_i.r.data);
      end

      if (mst_req_o.ar_valid && mst_resp_i.ar_ready) begin
         $display("[%0t] AR HANDSHAKE addr=%h len=%0d id=%0d",
                  $time,
                  mst_req_o.ar.addr,
                  mst_req_o.ar.len,
                  mst_req_o.ar.id);
      end

      if (npu_core_valid && npu_core_ready) begin
         $display("[%0t] AXIS RX data=%h last=%0d",
                  $time,
                  npu_core_data,
                  npu_core_last);
      end

      if (mst_req_o.ar_valid && mst_resp_i.ar_ready)
        ar_count <= ar_count + 1;

      if (mst_resp_i.r_valid && mst_req_o.r_ready)
        r_count <= r_count + 1;
   end

endmodule
