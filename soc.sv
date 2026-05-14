// soc.sv
`include "axi_typedefs.svh"

module soc #(
	     parameter int unsigned SocAddrWidth = 32,
	     parameter int unsigned SocDataWidth = 64,
	     parameter int unsigned SocIdWidth = 4
	     // No "parameter type" here anymore!
	     ) (
		input logic clk_i,
		input logic rst_ni,
		input	    req_t ext_mst_req_i,
		output	    resp_t ext_mst_resp_o
		);

   // General flow of signals
   // 1. CPU (BFM) drives bfm_req.
   // 2. bfm_req is assigned to slv_reqs[0] (The Crossbar's "front door").
   // 3. Xbar looks at slv_reqs[0], checks the AddrTable, and passes it to mst_reqs[0].
   // 4. RAM receives mst_reqs[0] and performs the write.
   // 5. The Return Path: The RAM response comes back through mst_resps[0] ->  Xbar $\rightarrow$ slv_resps[0] -> bfm_resp.

   // Arrays for Xbar
   req_t  [1:0] slv_reqs; // two masters for now
   resp_t [1:0] slv_resps;
   req_t  [0:0] mst_reqs; // one slave for now
   resp_t [0:0] mst_resps;

   req_t  bfm_req;
   resp_t bfm_resp;

   assign slv_reqs[0]    = bfm_req; // connect to xbar "front door"
   assign bfm_resp    = slv_resps[0];
   //assign ext_mst_resp_o = slv_resps[0];

   // Instantiate BFM
   cpu_bfm i_cpu_bfm (
		      .clk_i          (clk_i),
		      .rst_ni         (rst_ni),
		      .ext_mst_req_o  (bfm_req), 
		      .ext_mst_resp_i (bfm_resp) 
		      );

   // ---------------------------
   // 2. AXI Interconnect (Xbar)
   // ---------------------------
   // Define the Address Map (SRAM at 0x0000_0000 - 0x0000_FFFF)
   localparam		    axi_pkg::xbar_rule_32_t [0:0] AddrTable = '{
									'{
									  idx:        32'd0, 
									  start_addr: 32'h0000_0000,
									  end_addr:   32'h0000_FFFF
									  }
									};

   // Configuration struct for the Xbar
   localparam		    axi_pkg::xbar_cfg_t XbarCfg = '{
							    NoSlvPorts:         32'd2,
							    NoMstPorts:         32'd1,
							    MaxMstTrans:        4,
							    MaxSlvTrans:        4,
							    FallThrough:        1'b1,
							    LatencyMode:        axi_pkg::NO_LATENCY,
							    PipelineStages:     0,
							    AxiIdWidthSlvPorts: SocIdWidth,
							    AxiIdUsedSlvPorts:  SocIdWidth,
							    UniqueIds:          1'b0,
							    AxiAddrWidth:       SocAddrWidth,
							    AxiDataWidth:       SocDataWidth,
							    NoAddrRules:        32'd1
							    };

   axi_xbar #(
              .Cfg           ( XbarCfg ),
              .ATOPs         ( 1'b0 ), // Correct: Disabling this avoids the atop_filter error
              // Top-level types
              .slv_req_t     ( req_t ),
              .slv_resp_t    ( resp_t ),
              .mst_req_t     ( req_t ),
              .mst_resp_t    ( resp_t ),
              // Channel-specific types (CRITICAL for Verilator)
              .slv_aw_chan_t ( soc_axi_aw_chan_t ),
              .mst_aw_chan_t ( soc_axi_aw_chan_t ),
              .w_chan_t      ( soc_axi_w_chan_t  ),
              .slv_b_chan_t  ( soc_axi_b_chan_t  ),
              .mst_b_chan_t  ( soc_axi_b_chan_t  ),
              .slv_ar_chan_t ( soc_axi_ar_chan_t ),
              .mst_ar_chan_t ( soc_axi_ar_chan_t ),
              .slv_r_chan_t  ( soc_axi_r_chan_t  ),
              .mst_r_chan_t  ( soc_axi_r_chan_t  ),
              .rule_t        ( axi_pkg::xbar_rule_32_t )
	      ) i_xbar (
			.clk_i                  ( clk_i ),
			.rst_ni                 ( rst_ni ),
			.test_i                 ( 1'b0 ),
			.slv_ports_req_i        ( slv_reqs ),
			.slv_ports_resp_o       ( slv_resps ),
			.mst_ports_req_o        ( mst_reqs ),
			.mst_ports_resp_i       ( mst_resps ),
			.addr_map_i             ( AddrTable ),
			.en_default_mst_port_i  ( 1'b0 ),
			.default_mst_port_i     ( '0 )
			);

   // ---------------------------
   // 3. AXI RAM Module (Slave Node)
   // ---------------------------
   axi_ram_module #(
		    .AddrWidth ( SocAddrWidth ),
		    .DataWidth ( SocDataWidth ),
		    .IdWidth   ( SocIdWidth   ),
		    .MemDepth  ( 1024         ),
		    // Use the explicit types from your header/package
		    .axi_req_t ( req_t        ), 
		    .axi_resp_t( resp_t       )
		    ) i_ram_slave_0 (
				     .clk_i      ( clk_i ),
				     .rst_ni     ( rst_ni ),
				     .axi_req_i  ( mst_reqs[0] ),
				     .axi_resp_o ( mst_resps[0] ),
				     .busy_o     ( ) 
				     );

   npu_wrapper #(
		 .NumMasters ( 1 ) // Only one master for now (the rd_dma)
		 ) i_npu_top (
			      .clk_i      ( clk_i ),
			      .rst_ni     ( rst_ni ),
			      .mst_req_o  ( slv_reqs[1] ),  // Connect NPU Master to Xbar Slave Port 1
			      .mst_req_i  ( slv_resps[1] )
			      );
endmodule
