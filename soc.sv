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
		// If these are coming from an external Master (like a secondary CPU)
		input	    slv_req_t ext_mst_req_i, 
		output	    slv_resp_t ext_mst_resp_o,

		// If these are going to an external Slave (like off-chip Flash)
		output	    mst_req_t ext_slv_req_o,
		input	    mst_resp_t ext_slv_resp_i
		);

   // General flow of signals
   // 1. CPU (BFM) drives bfm_req.
   // 2. bfm_req is assigned to slv_reqs[0] (The Crossbar's "front door").
   // 3. Xbar looks at slv_reqs[0], checks the AddrTable, and passes it to mst_reqs[0].
   // 4. RAM receives mst_reqs[0] and performs the write.
   // 5. The Return Path: The RAM response comes back through mst_resps[0] ->  Xbar $\rightarrow$ slv_resps[0] -> bfm_resp.

   // Arrays for Xbar
   // Slave Ports: Connected to the CPU and NPU (4-bit IDs)
   slv_req_t  slv_reqs  [1:0]; 
   slv_resp_t slv_resps [1:0];

   // Master Ports: Connected to the Bridge/SRAM (5-bit IDs)
   mst_req_t  mst_reqs  [0:0]; 
   mst_resp_t mst_resps [0:0];

   slv_req_t  bfm_req;  // Correct: Using the 4-bit ID type
   slv_resp_t bfm_resp;

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
							    MaxMstTrans:        32'd8,
							    MaxSlvTrans:        32'd8,
							    FallThrough:        1'b1,
							    LatencyMode:        axi_pkg::NO_LATENCY,
							    AxiIdWidthSlvPorts: 4,  // Input from NPU/CPU
							    AxiIdUsedSlvPorts:  4,
							    //AxiIdWidthMstPorts: 5,  // Output to Bridge (with prefix)
							    AxiAddrWidth:       32,
							    AxiDataWidth:       64,
							    NoAddrRules:        32'd1,
							    UniqueIds:          1'b0, // Required for XBAR to add prefixes
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
		        .clk_i         ( clk_i   ), // Explicit clock
			.rst_ni        ( rst_ni  ), // Explicit reset
			.test_i        ( 1'b0    ),
			.slv_ports_req_i  ( {slv_reqs[1],  slv_reqs[0]}  ), 
			.slv_ports_resp_o ( {slv_resps[1], slv_resps[0]} ),
			.mst_ports_req_o  ( {mst_reqs[0]} ), // Even if only one master port
			.mst_ports_resp_i ( {mst_resps[0]} ),
			.addr_map_i       ( AddrTable ),
			.en_default_mst_port_i ( 1'b0 ),
			.default_mst_port_i    ( '0 )
			);

   // ---------------------------
   // 3. AXI RAM Module (Slave Node)
   // ---------------------------
   axi_ram_module #(
		    .AddrWidth ( SocAddrWidth ),
		    .DataWidth ( SocDataWidth ),
		    .IdWidth   ( 5           ), // Expanded width (SocIdWidth + 1)
		    .MemDepth  ( 2048        ),
		    .axi_req_t ( mst_req_t   ), // The 5-bit struct type
		    .axi_resp_t( mst_resp_t  )  // The 5-bit struct type
		    ) i_ram_slave_0 (
			     .clk_i     ( clk_i       ),
			     .rst_ni    ( rst_ni      ),
			     .axi_req_i ( mst_reqs[0] ), // Coming from XBAR Master port
			     .axi_resp_o( mst_resps[0]),
			     .busy_o    (             )
			     );

   
   npu_wrapper #(
		 .NumMasters ( 1 ), // Only one master for now (the rd_dma)
		 .axi_req_t ( slv_req_t        ), 
		 .axi_resp_t( slv_resp_t       )
		 ) i_npu_top (
			      .clk_i      ( clk_i ),
			      .rst_ni     ( rst_ni ),
			      .mst_req_o  ( slv_reqs[1] ),  // Connect NPU Master to Xbar Slave Port 1
			      .mst_resp_i  ( slv_resps[1] )
			      );
endmodule
