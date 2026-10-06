// =========================================================================
// Module: soc.sv
// Description:
// Version with ZERO REGISTERING / PURE COMBINATIONAL FEEDTHROUGH
// and an exhaustive Human-Readable Interconnect Diagnostic Engine.
// UPDATED: 5x4 Crossbar to integrate SPI Slave Autonomous Bus Master
// =========================================================================

`include "axi_typedefs.svh"

module soc #(
	     parameter int unsigned SocAddrWidth = 32,
	     parameter int unsigned SocDataWidth = 64,
	     parameter int unsigned SocIdWidth = 4
	     )(
	       input logic	  clk_i,
	       input logic	  rst_ni,

	       // =========================================================================
	       // EXTERNAL SPI SLAVE INTERFACE PINS
	       // =========================================================================
	       input logic	  test_mode_i,
	       input logic	  spi_sclk_i,
	       input logic	  spi_cs_i,
	       output logic [1:0] spi_mode_o,
	       input logic	  spi_sdi0_i,
	       input logic	  spi_sdi1_i,
	       input logic	  spi_sdi2_i,
	       input logic	  spi_sdi3_i,
	       output logic	  spi_sdo0_o,
	       output logic	  spi_sdo1_o,
	       output logic	  spi_sdo2_o,
	       output logic	  spi_sdo3_o
	       );

   // =========================================================================
   // 1. INTERCONNECT STRUCTURE ARRAYS (Expanded to 5 Requesting Masters)
   // =========================================================================

   slv_req_t  [4:0] slv_reqs;
   slv_resp_t [4:0] slv_resps;

   mst_req_t  [3:0] mst_reqs;
   mst_resp_t [3:0] mst_resps;

   // =========================================================================
   // 2. CPU BFM & SPI BRIDGE STRUCT WIRES
   // =========================================================================

   slv_req_t  bfm_req;
   slv_resp_t bfm_resp;

   assign slv_reqs[0] = bfm_req;
   assign bfm_resp    = slv_resps[0];

   slv_req_t  spi_req;
   slv_resp_t spi_resp;

   //assign slv_reqs[4] = spi_req;
   assign slv_reqs[4] = '0; // tmp tie off
   assign spi_resp    = slv_resps[4];

   // temp tieoffs
   assign spi_req = '0;
   

   // =========================================================================
   // 3. UNREGISTERED COMBINATIONAL XBAR INPUT STAGE
   // =========================================================================

   // Crossbar Input Request signals (5 Requesting Master Ports)
   slv_req_t  [4:0] xbar_slv_reqs_q;

   // Responses from xbar (5 Requesting Master Ports)
   slv_resp_t [4:0] xbar_slv_resps;

   // Master side (4 Target Ports)
   mst_req_t  [3:0] xbar_mst_reqs;
   mst_resp_t [3:0] xbar_mst_resps;

   // -------------------------------------------------------------------------
   // DIRECT COMBINATIONAL CONNECTIONS (No registers used)
   // -------------------------------------------------------------------------
   assign xbar_slv_reqs_q[0] = slv_reqs[0];
   assign xbar_slv_reqs_q[1] = slv_reqs[1];
   assign xbar_slv_reqs_q[2] = slv_reqs[2];
   assign xbar_slv_reqs_q[3] = slv_reqs[3]; // CPU_S Port
   assign xbar_slv_reqs_q[4] = slv_reqs[4]; // SPI Slave Bridge Port

   assign slv_resps[0] = xbar_slv_resps[0];
   assign slv_resps[1] = xbar_slv_resps[1];
   assign slv_resps[2] = xbar_slv_resps[2];
   assign slv_resps[3] = xbar_slv_resps[3]; // CPU_S Port
   assign slv_resps[4] = xbar_slv_resps[4]; // SPI Slave Bridge Port

   // =========================================================================
   // 4. MASTER PORT CONNECTIONS
   // =========================================================================

   assign mst_reqs[0] = xbar_mst_reqs[0];
   assign mst_reqs[1] = xbar_mst_reqs[1];
   assign mst_reqs[2] = xbar_mst_reqs[2];
   assign mst_reqs[3] = xbar_mst_reqs[3];

   assign xbar_mst_resps[0] = mst_resps[0];
   assign xbar_mst_resps[1] = mst_resps[1];
   assign xbar_mst_resps[2] = mst_resps[2];
   assign xbar_mst_resps[3] = mst_resps[3];

   // =========================================================================
   // 5. ISOLATED TARGET WIRES
   // =========================================================================

   mst_req_t  ram_exec_isolated_req;
   mst_resp_t ram_exec_isolated_resp;

   mst_req_t  npu_config_isolated_req;
   mst_resp_t npu_config_isolated_resp;

   mst_req_t  ds_config_isolated_req;
   mst_resp_t ds_config_isolated_resp;

   mst_req_t  ram_data_isolated_req;
   mst_resp_t ram_data_isolated_resp;

   // Target 0: Executable RAM (PicoRV32 Executable Only)
   assign ram_exec_isolated_req = mst_reqs[0];
   assign mst_resps[0]          = ram_exec_isolated_resp;

   // Target 1: NPU Config
   assign npu_config_isolated_req = mst_reqs[1];
   assign mst_resps[1]            = npu_config_isolated_resp;

   // Target 2: Data Sampler Config
   assign ds_config_isolated_req = mst_reqs[2];
   assign mst_resps[2]           = ds_config_isolated_resp;

   // Target 3: Data RAM (For DMAs / Shared Data Storage)
   assign ram_data_isolated_req = mst_reqs[3];
   assign mst_resps[3]          = ram_data_isolated_resp;

   // =========================================================================
   // 6. ADDRESS MAP
   // =========================================================================

   typedef axi_pkg::xbar_rule_32_t my_xbar_rule_t;

   localparam			 my_xbar_rule_t [3:0] xbar_addr_map = '{
									'{
									  idx:        32'd3, // Data/DMA SRAM
									  start_addr: 32'h10000000,
									  end_addr:   32'h1000FFFF // 64KB Data SRAM
									  },
									'{
									  idx:        32'd2, // Data Sampler Config (Peripheral MMIO)
									  start_addr: 32'h40010000,
									  end_addr:   32'h4001FFFF
									  },
									'{
									  idx:        32'd1, // NPU Config (Peripheral MMIO)
									  start_addr: 32'h40000000,
									  end_addr:   32'h4000FFFF
									  },
									'{
									  idx:        32'd0, // Executable SRAM (Boot Space)
									  start_addr: 32'h00000000,
									  end_addr:   32'h0000FFFF // 64KB Exec SRAM
									  }
									};

   // =========================================================================
   // 7. CPU BFM & PICO INSTANTIATION
   // =========================================================================

   cpu_bfm i_cpu_bfm (
		      .clk_i          ( clk_i ),
		      .rst_ni         ( rst_ni ),
		      .ext_mst_req_o  ( bfm_req ),
		      .ext_mst_resp_i ( bfm_resp )
		      );

   cpu_picorv32_axi #(
		      .axi_req_t       ( slv_req_t ),
		      .axi_resp_t      ( slv_resp_t ),
		      .axi_lite_req_t  ( axi_lite_req_t ),
		      .axi_lite_resp_t ( axi_lite_resp_t ),
		      .AxiDataWidth    ( SocDataWidth )
		      ) i_cpu_picorv32 (
					.clk        ( clk_i ),
					.resetn     ( rst_ni ),
					.cpu_trap   ( /* connect to a top-level pin or monitor */ ),
					.axi_req_o  ( slv_reqs[3] ),
					.axi_resp_i ( slv_resps[3] )
					//.axi_req_o  ( ),
					//.axi_resp_i ( )
					);

   // =========================================================================
   // 8. XBAR CONFIG (Expanded for 5x4 Interconnect)
   // =========================================================================

   localparam			 axi_pkg::xbar_cfg_t XbarCfg = '{
								 NoSlvPorts:         32'd5, // Expanded to 5 Requesting Master Ports
								 NoMstPorts:         32'd4, // 4 Target Memory/Peripheral Ports
								 MaxMstTrans:        32'd8,
								 MaxSlvTrans:        32'd8,
								 FallThrough:        1'b0,
								 LatencyMode:        axi_pkg::CUT_ALL_AX,
								 AxiIdWidthSlvPorts: 4,     // Matches TB_ID_W_SLV from axi_typedefs.svh
								 AxiIdUsedSlvPorts:  4,
								 AxiAddrWidth:       32,    // Matches TB_ADDR_W
								 AxiDataWidth:       64,    // Matches TB_DATA_W
								 NoAddrRules:        32'd4,
								 UniqueIds:          1'b0,
								 PipelineStages:     0
								 };

   // Rows = Requesting Masters (5), Columns = Targets (4) -> [Target 3, Target 2, Target 1, Target 0]
   localparam bit [4:0][3:0]	 XbarConnectivity = '{
						      '{1'b1, 1'b1, 1'b1, 1'b1}, // Port 4: SPI Slave Bridge sees Exec RAM, NPU Cfg, Sampler Cfg, Data RAM
						      '{1'b1, 1'b1, 1'b1, 1'b1}, // Port 3: CPU_S (PicoRV32)
						      '{1'b1, 1'b1, 1'b1, 1'b1}, // Port 2: Data Sampler (DMA)
						      '{1'b1, 1'b1, 1'b1, 1'b1}, // Port 1: NPU (DMA)
						      '{1'b1, 1'b1, 1'b1, 1'b1}  // Port 0: CPU_L (BFM)
						      };

   // =========================================================================
   // 9. AXI XBAR
   // =========================================================================

   axi_xbar #(
	      .Cfg            ( XbarCfg ),
	      .slv_req_t      ( slv_req_t ),
	      .slv_resp_t     ( slv_resp_t ),
	      .mst_req_t      ( mst_req_t ),
	      .mst_resp_t     ( mst_resp_t ),
	      .slv_aw_chan_t  ( slv_aw_chan_t ),
	      .mst_aw_chan_t  ( mst_aw_chan_t ),
	      .w_chan_t       ( slv_w_chan_t ),
	      .slv_b_chan_t   ( slv_b_chan_t ),
	      .mst_b_chan_t   ( mst_b_chan_t ),
	      .slv_ar_chan_t  ( slv_ar_chan_t ),
	      .mst_ar_chan_t  ( mst_ar_chan_t ),
	      .slv_r_chan_t   ( slv_r_chan_t ),
	      .mst_r_chan_t   ( mst_r_chan_t ),
	      .rule_t         ( my_xbar_rule_t ),
	      .Connectivity   ( XbarConnectivity )
	      ) i_xbar (
			.clk_i                 ( clk_i ),
			.rst_ni                ( rst_ni ),
			.test_i                ( 1'b0 ),

			.slv_ports_req_i       ( xbar_slv_reqs_q ),
			.slv_ports_resp_o      ( xbar_slv_resps ),

			.mst_ports_req_o       ( xbar_mst_reqs ),
			.mst_ports_resp_i      ( xbar_mst_resps ),

			.addr_map_i            ( xbar_addr_map ),

			.en_default_mst_port_i ( '0 ),
			.default_mst_port_i    ( '0 )
			);

   // =========================================================================
   // 10. TARGETS & PERIPHERALS
   // =========================================================================

   // Target 0: Executable SRAM Module
   axi_ram_module #(
		    .AddrWidth ( SocAddrWidth ),
		    .DataWidth ( SocDataWidth ),
		    .IdWidth   ( 8 ),
		    .MemDepth  ( 1024 ),
		    .InitFile  ( "/home/mikail/digital-design/Edge-MPSoC/app/firmware.hex" ),
		    .axi_req_t ( mst_req_t ),
		    .axi_resp_t( mst_resp_t )
		    ) i_ram_exec_slave_0 (
					  .clk_i      ( clk_i ),
					  .rst_ni     ( rst_ni ),
					  .axi_req_i  ( ram_exec_isolated_req ),
					  .axi_resp_o ( ram_exec_isolated_resp ),
					  .busy_o     ( )
					  );

   // Target 1: NPU Co-processor Configuration Port
   npu_wrapper #(
		 .NumMasters      ( 1 ),
		 .axi_cfg_req_t   ( mst_req_t ),
		 .axi_cfg_resp_t  ( mst_resp_t ),
		 .axi_data_req_t  ( slv_req_t ),
		 .axi_data_resp_t ( slv_resp_t )
		 ) i_npu_top (
			      .clk_i      ( clk_i ),
			      .rst_ni     ( rst_ni ),

			      .slv_req_i  ( npu_config_isolated_req ),
			      .slv_resp_o ( npu_config_isolated_resp ),

			      .mst_req_o  ( slv_reqs[1] ),
			      .mst_resp_i ( slv_resps[1] )
			      );

   // Target 2: Data Sampler Module Configuration Port
   data_sampler #(
		  .NumMasters      ( 1 ),
		  .axi_cfg_req_t   ( mst_req_t ),
		  .axi_cfg_resp_t  ( mst_resp_t ),
		  .axi_data_req_t  ( slv_req_t ),
		  .axi_data_resp_t ( slv_resp_t )
		  ) i_data_sampler (
				    .clk_i      ( clk_i ),
				    .rst_ni     ( rst_ni ),

				    .slv_req_i  ( ds_config_isolated_req ),
				    .slv_resp_o ( ds_config_isolated_resp ),

				    .mst_req_o  ( slv_reqs[2] ),
				    .mst_resp_i ( slv_resps[2] )
				    );

   // Target 3: Data/DMA SRAM Module
   axi_ram_module #(
		    .AddrWidth ( SocAddrWidth ),
		    .DataWidth ( SocDataWidth ),
		    .IdWidth   ( 8 ),
		    .MemDepth  ( 1024 ),
		    .InitFile  ( "/home/mikail/digital-design/Edge-MPSoC/modules/sram_node/sram_init.mem" ),
		    .axi_req_t ( mst_req_t ),
		    .axi_resp_t( mst_resp_t )
		    ) i_ram_data_slave_3 (
					  .clk_i      ( clk_i ),
					  .rst_ni     ( rst_ni ),
					  .axi_req_i  ( ram_data_isolated_req ),
					  .axi_resp_o ( ram_data_isolated_resp ),
					  .busy_o     ( )
					  );

   // =========================================================================
   // 11. SPI SLAVE TO AXI MASTER BRIDGE INSTANTIATION
   // =========================================================================

   axi_spi_slave #(
		   .AXI_ADDR_WIDTH ( SocAddrWidth ), // 32
		   .AXI_DATA_WIDTH ( SocDataWidth ), // 64
		   .AXI_USER_WIDTH ( 1 ),            // TB_USER_W
		   .AXI_ID_WIDTH   ( SocIdWidth ),   // 4 (TB_ID_W_SLV)
		   .DUMMY_CYCLES   ( 32 )
		   ) u_axi_spi_slave (
				      .test_mode           ( test_mode_i ),
				      .spi_sclk            ( spi_sclk_i ),
				      .spi_cs              ( spi_cs_i ),
				      .spi_mode            ( spi_mode_o ),
				      .spi_sdi0            ( spi_sdi0_i ),
				      .spi_sdi1            ( spi_sdi1_i ),
				      .spi_sdi2            ( spi_sdi2_i ),
				      .spi_sdi3            ( spi_sdi3_i ),
				      .spi_sdo0            ( spi_sdo0_o ),
				      .spi_sdo1            ( spi_sdo1_o ),
				      .spi_sdo2            ( spi_sdo2_o ),
				      .spi_sdo3            ( spi_sdo3_o ),

				      // AXI4 Clock & Reset
				      .axi_aclk            ( clk_i ),
				      .axi_aresetn         ( rst_ni ),

				      // WRITE ADDRESS CHANNEL
				      .axi_master_aw_valid ( spi_req.aw_valid ),
				      .axi_master_aw_addr  ( spi_req.aw.addr ),
				      .axi_master_aw_prot  ( spi_req.aw.prot ),
				      .axi_master_aw_region( spi_req.aw.region ),
				      .axi_master_aw_len   ( spi_req.aw.len ),
				      .axi_master_aw_size  ( spi_req.aw.size ),
				      .axi_master_aw_burst ( spi_req.aw.burst ),
				      .axi_master_aw_lock  ( spi_req.aw.lock ),
				      .axi_master_aw_cache ( spi_req.aw.cache ),
				      .axi_master_aw_qos   ( spi_req.aw.qos ),
				      .axi_master_aw_id    ( spi_req.aw.id ),
				      .axi_master_aw_user  ( spi_req.aw.user ),
				      .axi_master_aw_ready ( spi_resp.aw_ready ),

				      // READ ADDRESS CHANNEL
				      .axi_master_ar_valid ( spi_req.ar_valid ),
				      .axi_master_ar_addr  ( spi_req.ar.addr ),
				      .axi_master_ar_prot  ( spi_req.ar.prot ),
				      .axi_master_ar_region( spi_req.ar.region ),
				      .axi_master_ar_len   ( spi_req.ar.len ),
				      .axi_master_ar_size  ( spi_req.ar.size ),
				      .axi_master_ar_burst ( spi_req.ar.burst ),
				      .axi_master_ar_lock  ( spi_req.ar.lock ),
				      .axi_master_ar_cache ( spi_req.ar.cache ),
				      .axi_master_ar_qos   ( spi_req.ar.qos ),
				      .axi_master_ar_id    ( spi_req.ar.id ),
				      .axi_master_ar_user  ( spi_req.ar.user ),
				      .axi_master_ar_ready ( spi_resp.ar_ready ),

				      // WRITE DATA CHANNEL
				      .axi_master_w_valid  ( spi_req.w_valid ),
				      .axi_master_w_data   ( spi_req.w.data ),
				      .axi_master_w_strb   ( spi_req.w.strb ),
				      .axi_master_w_user   ( spi_req.w.user ),
				      .axi_master_w_last   ( spi_req.w.last ),
				      .axi_master_w_ready  ( spi_resp.w_ready ),

				      // READ DATA CHANNEL
				      .axi_master_r_valid  ( spi_resp.r_valid ),
				      .axi_master_r_data   ( spi_resp.r.data ),
				      .axi_master_r_resp   ( spi_resp.r.resp ),
				      .axi_master_r_last   ( spi_resp.r.last ),
				      .axi_master_r_id     ( spi_resp.r.id ),
				      .axi_master_r_user   ( spi_resp.r.user ),
				      .axi_master_r_ready  ( spi_req.r_ready ),

				      // WRITE RESPONSE CHANNEL
				      .axi_master_b_valid  ( spi_resp.b_valid ),
				      .axi_master_b_resp   ( spi_resp.b.resp ),
				      .axi_master_b_id     ( spi_resp.b.id ),
				      .axi_master_b_user   ( spi_resp.b.user ),
				      .axi_master_b_ready  ( spi_req.b_ready )
				      );

   // ============================================================================
   // SIMULATION-ONLY DEBUG TRACKER & PROTOCOL CHECKER
   // ============================================================================

`ifndef SYNTHESIS
   
   initial begin
      $display("\n[SOC_Interconnect_Engine] Ordered Tracking & Protocol Compliance Active.");
   end

   // ----------------------------------------------------------------------------
   // PHASE 1: AXI PROTOCOL COMPLIANCE CHECKS
   // ----------------------------------------------------------------------------
   always @(posedge clk_i) begin
      if (!rst_ni) begin
	 for (int i = 0; i < 5; i++) begin
	    if (xbar_slv_reqs_q[i].aw_valid || xbar_slv_reqs_q[i].ar_valid || xbar_slv_reqs_q[i].w_valid) begin
               $error("[AXI PROTOCOL VIOLATION] Slave Port %0d asserted VALID signals during active reset!", i);
	    end
	 end
	 for (int i = 0; i < 4; i++) begin
	    if (xbar_mst_reqs[i].aw_valid || xbar_mst_reqs[i].ar_valid || xbar_mst_reqs[i].w_valid) begin
               $error("[AXI PROTOCOL VIOLATION] XBAR Master Port %0d asserted VALID signals during active reset!", i);
	    end
	 end
      end

      if (rst_ni && $time > 10000) begin
	 for (int s = 0; s < 5; s++) begin
	    if ($past(xbar_slv_reqs_q[s].aw_valid) && !$past(xbar_slv_resps[s].aw_ready)) begin
               if (!xbar_slv_reqs_q[s].aw_valid)
		 $error("[AXI PROTOCOL VIOLATION] Slave Port %0d: AW_VALID dropped before AW_READY handshake!", s);
               if (xbar_slv_reqs_q[s].aw.addr != $past(xbar_slv_reqs_q[s].aw.addr))
		 $error("[AXI PROTOCOL VIOLATION] Slave Port %0d: AW_ADDR changed payload while waiting for AW_READY!", s);
	    end
	    if ($past(xbar_slv_reqs_q[s].ar_valid) && !$past(xbar_slv_resps[s].ar_ready)) begin
               if (!xbar_slv_reqs_q[s].ar_valid)
		 $error("[AXI PROTOCOL VIOLATION] Slave Port %0d: AR_VALID dropped before AR_READY handshake!", s);
               if (xbar_slv_reqs_q[s].ar.addr != $past(xbar_slv_reqs_q[s].ar.addr))
		 $error("[AXI PROTOCOL VIOLATION] Slave Port %0d: AR_ADDR changed payload while waiting for AR_READY!", s);
	    end
	    if ($past(xbar_slv_reqs_q[s].w_valid) && !$past(xbar_slv_resps[s].w_ready)) begin
               if (!xbar_slv_reqs_q[s].w_valid)
		 $error("[AXI PROTOCOL VIOLATION] Slave Port %0d: W_VALID dropped before W_READY handshake!", s);
               if (xbar_slv_reqs_q[s].w.data != $past(xbar_slv_reqs_q[s].w.data))
		 $error("[AXI PROTOCOL VIOLATION] Slave Port %0d: W_DATA mutated while waiting for W_READY!", s);
	    end
	 end

	 for (int m = 0; m < 4; m++) begin
	    if ($past(xbar_mst_resps[m].r_valid) && !$past(xbar_mst_reqs[m].r_ready)) begin
               if (!xbar_mst_resps[m].r_valid)
		 $error("[AXI PROTOCOL VIOLATION] Master Port %0d: R_VALID dropped before R_READY handshake!", m);
               if (xbar_mst_resps[m].r.data != $past(xbar_mst_resps[m].r.data))
		 $error("[AXI PROTOCOL VIOLATION] Master Port %0d: R_DATA mutated while waiting for R_READY!", m);
	    end
	 end
      end
   end

   // ----------------------------------------------------------------------------
   // PHASE 2: TRAFFIC LOGGING - INBOUND
   // ----------------------------------------------------------------------------
   always @(posedge clk_i) begin
      if (rst_ni) begin
	 for (int s = 0; s < 5; s++) begin
	    automatic string initiator = (s == 0) ? "CPU_L" : 
                      (s == 1) ? "NPU" : 
                      (s == 2) ? "SAMPLER" : 
                      (s == 3) ? "CPU_S" : "SPI_SLAVE";

	    if (xbar_slv_reqs_q[s].aw_valid && xbar_slv_resps[s].aw_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [%s WRITE] ---------- SLAVE PORT %0d: WRITE ADDRESS (AW) ----------", $time, initiator, s);
               $display("  AW_ADDR : 0x%8h", xbar_slv_reqs_q[s].aw.addr);
               $display("  AW_ID   : 0x%1h", xbar_slv_reqs_q[s].aw.id);
	    end
	    if (xbar_slv_reqs_q[s].w_valid && xbar_slv_resps[s].w_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [%s WRITE] ---------- SLAVE PORT %0d: WRITE DATA (W) -------------", $time, initiator, s);
               $display("  W_DATA  : 0x%16h", xbar_slv_reqs_q[s].w.data);
               $display("  W_LAST  : %1b", xbar_slv_reqs_q[s].w.last);
	    end
	    if (xbar_slv_reqs_q[s].ar_valid && xbar_slv_resps[s].ar_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [%s READ] ----------- SLAVE PORT %0d: READ ADDRESS (AR) -----------", $time, initiator, s);
               $display("  AR_ADDR : 0x%8h", xbar_slv_reqs_q[s].ar.addr);
               $display("  AR_ID   : 0x%1h", xbar_slv_reqs_q[s].ar.id);
	    end
	 end

	 for (int m = 0; m < 4; m++) begin
	    if (xbar_mst_resps[m].b_valid && xbar_mst_reqs[m].b_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [TYPE: WRITE] ---------- MASTER PORT %0d (%s): WRITE RESPONSE (B) --", $time, m, (m == 0) ? "RAM_EXEC" : (m == 1) ? "NPU" : (m == 2) ? "SAMPLER" : "RAM_DATA");
               $display("  B_ID    : 0x%1h", xbar_mst_resps[m].b.id);
               $display("  B_RESP  : 2'b%2b", xbar_mst_resps[m].b.resp);
	    end
	    if (xbar_mst_resps[m].r_valid && xbar_mst_reqs[m].r_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [TYPE: READ] ----------- MASTER PORT %0d (%s): READ DATA (R) -------", $time, m, (m == 0) ? "RAM_EXEC" : (m == 1) ? "NPU" : (m == 2) ? "SAMPLER" : "RAM_DATA");
               $display("  R_DATA  : 0x%16h", xbar_mst_resps[m].r.data);
               $display("  R_ID    : 0x%1h", xbar_mst_resps[m].r.id);
               $display("  R_LAST  : %1b", xbar_mst_resps[m].r.last);
	    end
	 end
      end
   end

   // ----------------------------------------------------------------------------
   // PHASE 3: TRAFFIC LOGGING - OUTBOUND
   // ----------------------------------------------------------------------------
   always @(posedge clk_i) begin
      if (rst_ni) begin
	 for (int m = 0; m < 4; m++) begin
	    if (xbar_mst_reqs[m].aw_valid && xbar_mst_resps[m].aw_ready) begin
               $display("\n<<< [TIME: %0t ps] [OUT OF XBAR] [TYPE: WRITE] --------- MASTER PORT %0d (%s): WRITE ADDRESS (AW) -", $time, m, (m == 0) ? "RAM_EXEC" : (m == 1) ? "NPU" : (m == 2) ? "SAMPLER" : "RAM_DATA");
               $display("  AW_ADDR : 0x%8h", xbar_mst_reqs[m].aw.addr);
               $display("  AW_ID   : 0x%1h", xbar_mst_reqs[m].aw.id);
	    end
	    if (xbar_mst_reqs[m].w_valid && xbar_mst_resps[m].w_ready) begin
               $display("\n<<< [TIME: %0t ps] [OUT OF XBAR] [TYPE: WRITE] --------- MASTER PORT %0d (%s): WRITE DATA (W) ------", $time, m, (m == 0) ? "RAM_EXEC" : (m == 1) ? "NPU" : (m == 2) ? "SAMPLER" : "RAM_DATA");
               $display("  W_DATA  : 0x%16h", xbar_mst_reqs[m].w.data);
               $display("  W_LAST  : %1b", xbar_mst_reqs[m].w.last);
	    end
	    if (xbar_mst_reqs[m].ar_valid && xbar_mst_resps[m].ar_ready) begin
               $display("\n<<< [TIME: %0t ps] [OUT OF XBAR] [TYPE: READ] ---------- MASTER PORT %0d (%s): READ ADDRESS (AR) --", $time, m, (m == 0) ? "RAM_EXEC" : (m == 1) ? "NPU" : (m == 2) ? "SAMPLER" : "RAM_DATA");
               $display("  AR_ADDR : 0x%8h", xbar_mst_reqs[m].ar.addr);
               $display("  AR_ID   : 0x%1h", xbar_mst_reqs[m].ar.id);
	    end
	 end

	 for (int s = 0; s < 5; s++) begin
	    automatic string initiator = (s == 0) ? "CPU_L" : 
                      (s == 1) ? "NPU" : 
                      (s == 2) ? "SAMPLER" : 
                      (s == 3) ? "CPU_S" : "SPI_SLAVE";

	    if (xbar_slv_resps[s].b_valid && xbar_slv_reqs_q[s].b_ready) begin
               $display("\n<<< [TIME: %0t ps] [OUT OF XBAR] [%s WRITE RESP] --------- SLAVE PORT %0d: WRITE RESPONSE (B) ---------", $time, initiator, s);
               $display("  B_ID    : 0x%1h", xbar_slv_resps[s].b.id);
               $display("  B_RESP  : 2'b%2b", xbar_slv_resps[s].b.resp);
	    end
	    if (xbar_slv_resps[s].r_valid && xbar_slv_reqs_q[s].r_ready) begin
               $display("\n<<< [TIME: %0t ps] [OUT OF XBAR] [%s READ RESP] ---------- SLAVE PORT %0d: READ DATA (R) ------------", $time, initiator, s);
               $display("  R_DATA  : 0x%16h", xbar_slv_resps[s].r.data);
               $display("  R_ID    : 0x%1h", xbar_slv_resps[s].r.id);
               $display("  R_LAST  : %1b", xbar_slv_resps[s].r.last);
	    end
	 end
      end
   end

   // ============================================================================
   // SIMULATION 'X' POISONING DETECTOR
   // ============================================================================
   // synopsys translate_off
   always_ff @(posedge clk_i) begin
      if (rst_ni) begin
	 if ($isunknown(ram_exec_isolated_resp.aw_ready))
	   $error("[FATAL X-DETECT] RAM_EXEC AW_READY is undefined ('X')");
	 if ($isunknown(ram_exec_isolated_resp.w_ready))
	   $error("[FATAL X-DETECT] RAM_EXEC W_READY is undefined ('X')");

	 if ($isunknown(npu_config_isolated_resp.aw_ready))
	   $error("[FATAL X-DETECT] NPU Config AW_READY is undefined ('X')");
	 if ($isunknown(npu_config_isolated_resp.w_ready))
	   $error("[FATAL X-DETECT] NPU Config W_READY is undefined ('X')");

	 if ($isunknown(ds_config_isolated_resp.aw_ready))
	   $error("[FATAL X-DETECT] Sampler Config AW_READY is undefined ('X')");
	 if ($isunknown(ds_config_isolated_resp.w_ready))
	   $error("[FATAL X-DETECT] Sampler Config W_READY is undefined ('X')");

	 if ($isunknown(ram_data_isolated_resp.aw_ready))
	   $error("[FATAL X-DETECT] RAM_DATA AW_READY is undefined ('X')");
	 if ($isunknown(ram_data_isolated_resp.w_ready))
	   $error("[FATAL X-DETECT] RAM_DATA W_READY is undefined ('X')");

	 if ($isunknown(bfm_resp.aw_ready))
	   $error("[FATAL X-DETECT] Crossbar -> CPU BFM AW_READY is undefined ('X')");
	 if ($isunknown(bfm_resp.w_ready))
	   $error("[FATAL X-DETECT] Crossbar -> CPU BFM W_READY is undefined ('X')");

	 if ($isunknown(spi_resp.aw_ready))
	   $error("[FATAL X-DETECT] Crossbar -> SPI Slave AW_READY is undefined ('X')");
	 if ($isunknown(spi_resp.w_ready))
	   $error("[FATAL X-DETECT] Crossbar -> SPI Slave W_READY is undefined ('X')");
      end
   end
   // synopsys translate_on

   // ============================================================================
   // AXI STALL TRACER
   // ============================================================================
   // synopsys translate_off
   always @(posedge clk_i) begin
      // Monitor SPI Slave (Port 4)
      if (slv_reqs[4].aw_valid && !slv_resps[4].aw_ready) begin
	 $display("[%0t] [STALL TRACE] SPI_SLAVE is driving AW_VALID=1, but Crossbar AW_READY=0", $time);
	 $display(" -> Route to RAM_EXEC : AW_VALID=%b | AW_READY=%b", mst_reqs[0].aw_valid, mst_resps[0].aw_ready);
	 $display(" -> Route to NPU      : AW_VALID=%b | AW_READY=%b", mst_reqs[1].aw_valid, mst_resps[1].aw_ready);
	 $display(" -> Route to SAMPLER  : AW_VALID=%b | AW_READY=%b", mst_reqs[2].aw_valid, mst_resps[2].aw_ready);
	 $display(" -> Route to RAM_DATA : AW_VALID=%b | AW_READY=%b", mst_reqs[3].aw_valid, mst_resps[3].aw_ready);
      end
   end
   // synopsys translate_on

`endif

endmodule
