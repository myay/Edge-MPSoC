// =========================================================================
// Module: soc.sv
// Description: Cleaned System-on-Chip top-level interconnect matrix.
//              Incorporates strict structural isolation to expose bypass bugs
//              and explicit array index tracking to eliminate concatenation traps.
// =========================================================================

`include "axi_typedefs.svh"

module soc #(
	     parameter int unsigned SocAddrWidth = 32,
	     parameter int unsigned SocDataWidth = 64,
	     parameter int unsigned SocIdWidth = 4
	     ) (
		input logic clk_i,
		input logic rst_ni
		);

   // =========================================================================
   // 1. INTERCONNECT STRUCTURE ARRAYS
   // =========================================================================
   // Slave Ports: Connected to Master Initiators (CPU @ Index 0, NPU @ Index 1)
   slv_req_t  slv_reqs  [1:0]; 
   slv_resp_t slv_resps [1:0];

   // Master Ports: Connected to Target Slaves (RAM @ Index 0, NPU Config @ Index 1)
   mst_req_t  mst_reqs  [1:0]; 
   mst_resp_t mst_resps [1:0];

   // Dedicated BFM local handshake wires
   slv_req_t  bfm_req;  
   slv_resp_t bfm_resp;

   // Establish Slave Port 0 explicit coupling
   assign slv_reqs[0] = bfm_req; 
   assign bfm_resp    = slv_resps[0];

   // =========================================================================
   // 2. INTERMEDIATE XBAR ARRAYS & EXPLICIT INDEX MAPPING
   // =========================================================================
   slv_req_t  [1:0] xbar_slv_reqs;
   slv_resp_t [1:0] xbar_slv_resps;
   mst_req_t  [1:0] xbar_mst_reqs;
   mst_resp_t [1:0] xbar_mst_resps;

   // Explicit Slave Port Assignments (Index-to-Index Alignment)
   assign xbar_slv_reqs[0] = slv_reqs[0]; // CPU Master to XBAR Slave Port 0
   assign xbar_slv_reqs[1] = slv_reqs[1]; // NPU Master to XBAR Slave Port 1
   
   assign slv_resps[0]     = xbar_slv_resps[0];
   assign slv_resps[1]     = xbar_slv_resps[1];

   // Explicit Master Port Assignments (Index-to-Index Alignment)
   assign mst_reqs[1]      = xbar_mst_reqs[0];  // XBAR Master Port 0 to SRAM
   assign mst_reqs[0]      = xbar_mst_reqs[1];  // XBAR Master Port 1 to NPU Config
   
   assign xbar_mst_resps[1] = mst_resps[0];
   assign xbar_mst_resps[0] = mst_resps[1];

   // =========================================================================
   // 3. ISOLATION NETS FOR SMOKE-TESTING BACKDOOR OVERRIDES
   // =========================================================================
   mst_req_t  ram_isolated_req;
   mst_resp_t ram_isolated_resp;

   mst_req_t  npu_config_isolated_req;
   mst_resp_t npu_config_isolated_resp;

   // Map crossbar core master array lanes to isolated point-to-point wires
   assign ram_isolated_req        = mst_reqs[0];
   assign mst_resps[0]            = ram_isolated_resp;

   assign npu_config_isolated_req = mst_reqs[1];
   assign mst_resps[1]            = npu_config_isolated_resp;

   // =========================================================================
   // 4. EXPLICIT ADDRESS MAP GENERATION 
   // =========================================================================
   // We keep this as an unpacked array to maintain your clean assignment structure.
   axi_pkg::xbar_rule_32_t [1:0] xbar_addr_map;

   // Slot [0]: System SRAM Range
   assign xbar_addr_map[0].idx        = 32'd0;
   assign xbar_addr_map[0].start_addr = 32'h0000_0000;
   assign xbar_addr_map[0].end_addr   = 32'h0000_FFFF;

   // Slot [1]: NPU Registers Range
   assign xbar_addr_map[1].idx        = 32'd1;
   assign xbar_addr_map[1].start_addr = 32'h0001_0000;
   assign xbar_addr_map[1].end_addr   = 32'h0001_FFFF;

   // =========================================================================
   // 5. INITIATOR MODULE INSTANTIATION (CPU BFM)
   // =========================================================================
   cpu_bfm i_cpu_bfm (
		      .clk_i          (clk_i),
		      .rst_ni         (rst_ni),
		      .ext_mst_req_o  (bfm_req), 
		      .ext_mst_resp_i (bfm_resp) 
		      );

   // =========================================================================
   // 6. AXI INTERCONNECT SYSTEM (AXI_XBAR)
   // =========================================================================
   localparam		    axi_pkg::xbar_cfg_t XbarCfg = '{
							    NoSlvPorts:         32'd2,
							    NoMstPorts:         32'd2,
							    MaxMstTrans:        32'd8,
							    MaxSlvTrans:        32'd8,
							    FallThrough:        1'b1,
							    LatencyMode:        axi_pkg::NO_LATENCY,
							    AxiIdWidthSlvPorts: 4,  
							    AxiIdUsedSlvPorts:  4,
							    AxiAddrWidth:       32,
							    AxiDataWidth:       64,
							    NoAddrRules:        32'd2,
							    UniqueIds:          1'b0, 
							    PipelineStages:     0
							    };

   axi_xbar #(
	      .Cfg           ( XbarCfg ),
	      .slv_req_t     ( slv_req_t ),
	      .slv_resp_t    ( slv_resp_t ),
	      .mst_req_t     ( mst_req_t ),
	      .mst_resp_t    ( mst_resp_t ),
	      .slv_aw_chan_t ( slv_aw_chan_t ),
	      .mst_aw_chan_t ( mst_aw_chan_t ),
	      .w_chan_t      ( slv_w_chan_t  ),
	      .slv_b_chan_t  ( slv_b_chan_t  ),
	      .mst_b_chan_t  ( mst_b_chan_t  ),
	      .slv_ar_chan_t ( slv_ar_chan_t ),
	      .mst_ar_chan_t ( mst_ar_chan_t ),
	      .slv_r_chan_t  ( slv_r_chan_t  ),
	      .mst_r_chan_t  ( mst_r_chan_t  ),
	      .rule_t        ( axi_pkg::xbar_rule_32_t ) 
	      ) i_xbar (
			.clk_i                 ( clk_i           ), 
			.rst_ni                ( rst_ni          ), 
			.test_i                ( 1'b0            ),
			
			.slv_ports_req_i       ( xbar_slv_reqs   ), 
			.slv_ports_resp_o      ( xbar_slv_resps  ),
			
			.mst_ports_req_o       ( xbar_mst_reqs   ), 
			.mst_ports_resp_i      ( xbar_mst_resps  ),
			
			.addr_map_i            (xbar_addr_map), 
			
			.en_default_mst_port_i ( 2'b00           ),
			.default_mst_port_i    ( 2'b00           )
			);

   // =========================================================================
   // 7. TARGET SYSTEM MODULES (SRAM & CO-PROCESSOR CORES)
   // =========================================================================
   
   // Target 0: System Memory Module
   axi_ram_module #(
		    .AddrWidth ( SocAddrWidth ),
		    .DataWidth ( SocDataWidth ),
		    .IdWidth   ( 5            ), 
		    .MemDepth  ( 2048         ),
		    .axi_req_t ( mst_req_t    ), 
		    .axi_resp_t( mst_resp_t   )  
		    ) i_ram_slave_0 (
				     .clk_i     ( clk_i            ),
				     .rst_ni    ( rst_ni           ),
				     .axi_req_i ( ram_isolated_req ), 
				     .axi_resp_o( ram_isolated_resp),
				     .busy_o    (                  )
				     );

   // Target 1 / Initiator 1: Neural Processing Accelerator Co-Processor
   npu_wrapper #(
		 .NumMasters     ( 1 ),          
		 .axi_cfg_req_t  ( mst_req_t  ), 
		 .axi_cfg_resp_t ( mst_resp_t ),
		 .axi_data_req_t ( slv_req_t  ),
		 .axi_data_resp_t( slv_resp_t )
		 ) i_npu_top (
			      .clk_i      ( clk_i   ),
			      .rst_ni     ( rst_ni  ),

			      // CONFIGURATION TARGET PATH
			      .slv_req_i  ( npu_config_isolated_req  ),
			      .slv_resp_o ( npu_config_isolated_resp ),

			      // ACCESS MASTER PATH
			      .mst_req_o  ( slv_reqs[1]  ),  
			      .mst_resp_i ( slv_resps[1] )
			      );

   // =========================================================================
   // 8. DIAGNOSTIC BUS AUDIT LOGGING SYSTEM
   // =========================================================================
   initial begin
      $display("-------------------------------------------------------------------------------------------------------");
      $display("[    TIMESTAMP  ] [DIRECTION] PORT INSTANCE MODULE     | TRANSACTION DESCRIPTION & BUS DATA METADATA");
      $display("-------------------------------------------------------------------------------------------------------");
   end

   always @(posedge clk_i) begin
      if (rst_ni) begin
         // Slave Port 0: CPU Input Interface
         if (slv_reqs[0].aw_valid && slv_resps[0].aw_ready) begin
            $display("[%14t] [XBAR_IN ] SLV_0_CPU  -> AW Fwd     | Addr: 0x%8h | ID: %1d | Ready: 1", 
                     $time, slv_reqs[0].aw.addr, slv_reqs[0].aw.id);
         end
         if (slv_reqs[0].w_valid && slv_resps[0].w_ready) begin
            $display("[%14t] [XBAR_IN ] SLV_0_CPU  -> W Fwd      | Data: 0x%8h_%8h | Strb: 0x%2h | Ready: 1", 
                     $time, slv_reqs[0].w.data[63:32], slv_reqs[0].w.data[31:0], slv_reqs[0].w.strb);
         end
         if (slv_resps[0].b_valid && slv_reqs[0].b_ready) begin
            $display("[%14t] [XBAR_OUT] SLV_0_CPU  <- B Return   | Resp: 0x%1b | ID: %1d | Ready: 1", 
                     $time, slv_resps[0].b.resp, slv_resps[0].b.id);
         end
         if (slv_reqs[0].ar_valid && slv_resps[0].ar_ready) begin
            $display("[%14t] [XBAR_IN ] SLV_0_CPU  -> AR Fwd     | Addr: 0x%8h | ID: %1d | Ready: 1", 
                     $time, slv_reqs[0].ar.addr, slv_reqs[0].ar.id);
         end
         if (slv_resps[0].r_valid && slv_reqs[0].r_ready) begin
            $display("[%14t] [XBAR_OUT] SLV_0_CPU  <- R Return   | Data: 0x%8h_%8h | ID: %1d | Last: %1b | Ready: 1", 
                     $time, slv_resps[0].r.data[63:32], slv_resps[0].r.data[31:0], slv_resps[0].r.id, slv_resps[0].r.last);
         end

         // Master Port 0: System RAM Interface
         if (ram_isolated_req.aw_valid && ram_isolated_resp.aw_ready) begin
            $display("[%14t] [XBAR_OUT] MST_0_RAM  <- AW Fwd     | Addr: 0x%8h | ID: %1d | Ready: 1", 
                     $time, ram_isolated_req.aw.addr, ram_isolated_req.aw.id);
         end
         if (ram_isolated_req.w_valid && ram_isolated_resp.w_ready) begin
            $display("[%14t] [XBAR_OUT] MST_0_RAM  <- W Fwd      | Data: 0x%8h_%8h | Strb: 0x%2h | Ready: 1", 
                     $time, ram_isolated_req.w.data[63:32], ram_isolated_req.w.data[31:0], ram_isolated_req.w.strb);
         end
         if (ram_isolated_resp.b_valid && ram_isolated_req.b_ready) begin
            $display("[%14t] [XBAR_IN ] MST_0_RAM  -> B Recv     | Resp: 0x%1b | ID: %1d | Ready: 1", 
                     $time, ram_isolated_resp.b.resp, ram_isolated_resp.b.id);
         end

         // Master Port 1: NPU Register Interface
         if (npu_config_isolated_req.aw_valid && npu_config_isolated_resp.aw_ready) begin
            $display("[%14t] [XBAR_OUT] MST_1_NPU  <- AW Fwd     | Addr: 0x%8h | ID: %1d | Ready: 1", 
                     $time, npu_config_isolated_req.aw.addr, npu_config_isolated_req.aw.id);
         end
         if (npu_config_isolated_req.w_valid && npu_config_isolated_resp.w_ready) begin
            $display("[%14t] [XBAR_OUT] MST_1_NPU  <- W Fwd      | Data: 0x%8h_%8h | Strb: 0x%2h | Ready: 1", 
                     $time, npu_config_isolated_req.w.data[63:32], npu_config_isolated_req.w.data[31:0], npu_config_isolated_req.w.strb);
         end
         if (npu_config_isolated_resp.b_valid && npu_config_isolated_req.b_ready) begin
            $display("[%14t] [XBAR_IN ] MST_1_NPU  -> B Recv     | Resp: 0x%1b | ID: %1d | Ready: 1", 
                     $time, npu_config_isolated_resp.b.resp, npu_config_isolated_resp.b.id);
         end
      end
   end

endmodule
