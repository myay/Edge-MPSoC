// =========================================================================
// Module: soc.sv
// Description:
//   Version with FULLY REGISTERED XBAR INPUT STRUCTS.
//
//   Goal:
//   Break all combinational timing/feedthrough paths between the BFM and
//   the AXI crossbar.
//
//   Important:
//   - Entire slv_req_t structs are registered before entering axi_xbar.
//   - Handshake responses are still directly connected back.
//   - This is intentionally "heavy-handed" for debug stabilization.
// =========================================================================

`include "axi_typedefs.svh"

module soc #(
	     parameter int unsigned SocAddrWidth = 32,
	     parameter int unsigned SocDataWidth = 64,
	     parameter int unsigned SocIdWidth = 4
	     )(
	       input logic clk_i,
	       input logic rst_ni
	       );

   // =========================================================================
   // 1. INTERCONNECT STRUCTURE ARRAYS
   // =========================================================================

   slv_req_t [1:0] slv_reqs;
   slv_resp_t [1:0] slv_resps;

   mst_req_t [1:0] mst_reqs;
   mst_resp_t [1:0] mst_resps;

   // =========================================================================
   // 2. CPU BFM WIRES
   // =========================================================================

   slv_req_t  bfm_req;
   slv_resp_t bfm_resp;

   assign slv_reqs[0] = bfm_req;
   assign bfm_resp    = slv_resps[0];

   // =========================================================================
   // 3. REGISTERED XBAR INPUT STAGE
   // =========================================================================

   // RAW inputs to register stage
   slv_req_t [1:0] xbar_slv_reqs_d;

   // REGISTERED outputs into xbar
   slv_req_t [1:0] xbar_slv_reqs_q;

   // Responses from xbar
   slv_resp_t [1:0] xbar_slv_resps;

   // Master side
   mst_req_t [1:0] xbar_mst_reqs;
   mst_resp_t [1:0] xbar_mst_resps;

   // -------------------------------------------------------------------------
   // RAW CONNECTIONS
   // -------------------------------------------------------------------------

   assign xbar_slv_reqs_d[0] = slv_reqs[0];
   assign xbar_slv_reqs_d[1] = slv_reqs[1];

   assign slv_resps[0] = xbar_slv_resps[0];
   assign slv_resps[1] = xbar_slv_resps[1];

   // -------------------------------------------------------------------------
   // FULL STRUCT REGISTRATION
   // -------------------------------------------------------------------------
   // TODO: use axi_cut, axi_fifo, axi_multicut for better slicing
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         xbar_slv_reqs_q[0] <= '0;
         xbar_slv_reqs_q[1] <= '0;
      end else begin
         xbar_slv_reqs_q[0] <= xbar_slv_reqs_d[0];
         xbar_slv_reqs_q[1] <= xbar_slv_reqs_d[1];
      end
   end

   // =========================================================================
   // 4. MASTER PORT CONNECTIONS
   // =========================================================================

   assign mst_reqs[0] = xbar_mst_reqs[0];
   assign mst_reqs[1] = xbar_mst_reqs[1];

   assign xbar_mst_resps[0] = mst_resps[0];
   assign xbar_mst_resps[1] = mst_resps[1];

   // =========================================================================
   // 5. ISOLATED TARGET WIRES
   // =========================================================================

   mst_req_t  ram_isolated_req;
   mst_resp_t ram_isolated_resp;

   mst_req_t  npu_config_isolated_req;
   mst_resp_t npu_config_isolated_resp;

   assign ram_isolated_req = mst_reqs[0];
   assign mst_resps[0]     = ram_isolated_resp;

   assign npu_config_isolated_req = mst_reqs[1];
   assign mst_resps[1]            = npu_config_isolated_resp;

   // =========================================================================
   // 6. ADDRESS MAP
   // =========================================================================

   typedef axi_pkg::xbar_rule_32_t my_xbar_rule_t;

   localparam my_xbar_rule_t [1:0] xbar_addr_map = '{
						     '{
						       idx:        32'd1,
						       start_addr: 32'h00010000,
						       end_addr:   32'h0001FFFF
						       },
						     '{
						       idx:        32'd0,
						       start_addr: 32'h00000000,
						       end_addr:   32'h0000FFFF
						       }
						     };

   // =========================================================================
   // 7. CPU BFM
   // =========================================================================

   cpu_bfm i_cpu_bfm (
		      .clk_i          ( clk_i   ),
		      .rst_ni         ( rst_ni  ),
		      .ext_mst_req_o  ( bfm_req ),
		      .ext_mst_resp_i ( bfm_resp )
		      );

   // =========================================================================
   // 8. XBAR CONFIG
   // =========================================================================

   localparam axi_pkg::xbar_cfg_t XbarCfg = '{
					      NoSlvPorts:         32'd2,
					      NoMstPorts:         32'd2,
					      MaxMstTrans:        32'd8,
					      MaxSlvTrans:        32'd8,
					      FallThrough:        1'b0,
					      LatencyMode:        axi_pkg::NO_LATENCY,
					      AxiIdWidthSlvPorts: 4,
					      AxiIdUsedSlvPorts:  4,
					      AxiAddrWidth:       32,
					      AxiDataWidth:       64,
					      NoAddrRules:        32'd2,
					      UniqueIds:          1'b0,
					      PipelineStages:     0
					      };

   localparam bit [1:0][1:0] XbarConnectivity = '{
						  '{1'b1, 1'b1},
						  '{1'b1, 1'b1}
						  };

   // =========================================================================
   // 9. AXI XBAR
   // =========================================================================

   axi_xbar #(
	      .Cfg              ( XbarCfg         ),
	      .slv_req_t        ( slv_req_t       ),
	      .slv_resp_t       ( slv_resp_t      ),
	      .mst_req_t        ( mst_req_t       ),
	      .mst_resp_t       ( mst_resp_t      ),
	      .slv_aw_chan_t    ( slv_aw_chan_t   ),
	      .mst_aw_chan_t    ( mst_aw_chan_t   ),
	      .w_chan_t         ( slv_w_chan_t    ),
	      .slv_b_chan_t     ( slv_b_chan_t    ),
	      .mst_b_chan_t     ( mst_b_chan_t    ),
	      .slv_ar_chan_t    ( slv_ar_chan_t   ),
	      .mst_ar_chan_t    ( mst_ar_chan_t   ),
	      .slv_r_chan_t     ( slv_r_chan_t    ),
	      .mst_r_chan_t     ( mst_r_chan_t    ),
	      .rule_t           ( my_xbar_rule_t  ),
	      .Connectivity     ( XbarConnectivity )
	      ) i_xbar (
			.clk_i                 ( clk_i             ),
			.rst_ni                ( rst_ni            ),
			.test_i                ( 1'b0              ),

			.slv_ports_req_i       ( xbar_slv_reqs_q   ),
			.slv_ports_resp_o      ( xbar_slv_resps    ),

			.mst_ports_req_o       ( xbar_mst_reqs     ),
			.mst_ports_resp_i      ( xbar_mst_resps    ),

			.addr_map_i            ( xbar_addr_map     ),

			.en_default_mst_port_i ( 2'b00             ),
			.default_mst_port_i    ( 2'b00             )
			);

   // =========================================================================
   // 10. TARGETS
   // =========================================================================

   axi_ram_module #(
		    .AddrWidth ( SocAddrWidth ),
		    .DataWidth ( SocDataWidth ),
		    .IdWidth   ( 5            ),
		    .MemDepth  ( 2048         ),
		    .axi_req_t ( mst_req_t    ),
		    .axi_resp_t( mst_resp_t   )
		    ) i_ram_slave_0 (
				     .clk_i      ( clk_i             ),
				     .rst_ni     ( rst_ni            ),
				     .axi_req_i  ( ram_isolated_req  ),
				     .axi_resp_o ( ram_isolated_resp ),
				     .busy_o     (                   )
				     );

   npu_wrapper #(
		 .NumMasters      ( 1          ),
		 .axi_cfg_req_t   ( mst_req_t  ),
		 .axi_cfg_resp_t  ( mst_resp_t ),
		 .axi_data_req_t  ( slv_req_t  ),
		 .axi_data_resp_t ( slv_resp_t )
		 ) i_npu_top (
			      .clk_i      ( clk_i                     ),
			      .rst_ni     ( rst_ni                    ),

			      .slv_req_i  ( npu_config_isolated_req   ),
			      .slv_resp_o ( npu_config_isolated_resp  ),

			      .mst_req_o  ( slv_reqs[1]               ),
			      .mst_resp_i ( slv_resps[1]              )
			      );
   // =========================================================================
   // 8. DIAGNOSTIC BUS AUDIT LOGGING SYSTEM
   // =========================================================================
   initial begin
      $display("-------------------------------------------------------------------------------------------------------");
      $display("[    TIMESTAMP  ] [DIRECTION] PORT INSTANCE MODULE     | TRANSACTION DESCRIPTION & BUS DATA METADATA");
      $display("-------------------------------------------------------------------------------------------------------");
      # 100;
      print_xbar_routes(32'd2, xbar_addr_map);

      // $display("ADDR=%h RULE0=[%h:%h] RULE1=[%h:%h]",
      // 	       xbar_slv_reqs[0].aw.addr,
      // 	       xbar_addr_map[0].start_addr,
      // 	       xbar_addr_map[0].end_addr,
      // 	       xbar_addr_map[1].start_addr,
      // 	       xbar_addr_map[1].end_addr);
      // $display("ADDR=%h RULE0=[%h:%h] RULE1=[%h:%h]",
      //          xbar_slv_reqs[0].aw.addr,
      //          RULE_RAM.start_addr,
      //          RULE_RAM.end_addr,
      //          RULE_NPU.start_addr,
      //          RULE_NPU.end_addr);
   end

   // Fix: Move the array dimension [2] to the right of the identifier name
   function automatic void print_xbar_routes(
					     input int unsigned	num_rules,
					     input		my_xbar_rule_t [1:0] rules 
					     );
      // Explicitly declare loop variable outside the loop header for strict compilers
      int unsigned						i; 
      
      $display("\n=== [XBAR RUNTIME ROUTING TABLE] ===");
      for (i = 0; i < num_rules; i++) begin
         $display(" Rule [%0d]:", i);
         $display("   ├── Start Address : 0x%8h", rules[i].start_addr);
         $display("   ├── End Address   : 0x%8h", rules[i].end_addr);
         $display("   └── Target Port ID: %0d",   rules[i].idx);
      end
      $display("=====================================\n");
   endfunction

   always @(posedge clk_i) begin
      if (rst_ni) begin

	 // if (xbar_mst_reqs[0].aw_valid)
	 //   $display("MST0 VALID addr=%h", xbar_mst_reqs[0].aw.addr);

	 // if (xbar_mst_reqs[1].aw_valid)
	 //   $display("MST1 VALID addr=%h", xbar_mst_reqs[1].aw.addr);
	 
	 // if (xbar_slv_reqs[0].aw_valid) begin
	 //    $display("ADDR = 0x%08h", xbar_slv_reqs[0].aw.addr);

	 //    if ((xbar_slv_reqs[0].aw.addr >= xbar_addr_map[0].start_addr) &&
	 // 	(xbar_slv_reqs[0].aw.addr <  xbar_addr_map[0].end_addr))
	 //      $display("MATCH RULE 0");

	 //    if ((xbar_slv_reqs[0].aw.addr >= xbar_addr_map[1].start_addr) &&
	 // 	(xbar_slv_reqs[0].aw.addr <  xbar_addr_map[1].end_addr))
	 //      $display("MATCH RULE 1");
	 // end
	 
	 // if (i_soc.xbar_slv_reqs[0].aw_valid) begin
	 //    $display("[DEBUG] Crossbar received AWADDR: 0x%h", i_soc.xbar_slv_reqs[0].aw.addr);
	 // end
	 
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
