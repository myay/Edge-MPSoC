// =========================================================================
// Module: soc.sv
// Description:
//    Version with ZERO REGISTERING / PURE COMBINATIONAL FEEDTHROUGH
//    and an exhaustive Human-Readable Interconnect Diagnostic Engine.
//    UPDATED: 4x4 Crossbar to support separate Executable and Data/DMA SRAMs
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
   // 1. INTERCONNECT STRUCTURE ARRAYS (Expanded to 4 Master/Target Ports)
   // =========================================================================

   slv_req_t [3:0] slv_reqs;
   slv_resp_t [3:0] slv_resps;

   mst_req_t [3:0] mst_reqs;
   mst_resp_t [3:0] mst_resps;

   // =========================================================================
   // 2. CPU BFM WIRES
   // =========================================================================

   slv_req_t  bfm_req;
   slv_resp_t bfm_resp;

   assign slv_reqs[0] = bfm_req;
   assign bfm_resp    = slv_resps[0];

   // =========================================================================
   // 3. UNREGISTERED COMBINATIONAL XBAR INPUT STAGE
   // =========================================================================

   // Crossbar Input Request signals 
   slv_req_t [3:0] xbar_slv_reqs_q;

   // Responses from xbar
   slv_resp_t [3:0] xbar_slv_resps;

   // Master side (4 Targets)
   mst_req_t [3:0] xbar_mst_reqs;
   mst_resp_t [3:0] xbar_mst_resps;

   // -------------------------------------------------------------------------
   // DIRECT COMBINATIONAL CONNECTIONS (No registers used)
   // -------------------------------------------------------------------------
   assign xbar_slv_reqs_q[0] = slv_reqs[0];
   assign xbar_slv_reqs_q[1] = slv_reqs[1];
   assign xbar_slv_reqs_q[2] = slv_reqs[2];
   assign xbar_slv_reqs_q[3] = slv_reqs[3]; // CPU_S Port

   assign slv_resps[0] = xbar_slv_resps[0];
   assign slv_resps[1] = xbar_slv_resps[1];
   assign slv_resps[2] = xbar_slv_resps[2];
   assign slv_resps[3] = xbar_slv_resps[3]; // CPU_S Port

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

   localparam		   my_xbar_rule_t [3:0] xbar_addr_map = '{
								  3: '{
								       idx:        32'd3, // Data/DMA SRAM
								       start_addr: 32'h10000000,
								       end_addr:   32'h1000FFFF // 64KB Data SRAM
								       },
								  2: '{
								       idx:        32'd2, // Data Sampler Config (Peripheral MMIO)
								       start_addr: 32'h40010000,
								       end_addr:   32'h4001FFFF
								       },
								  1: '{
								       idx:        32'd1, // NPU Config (Peripheral MMIO)
								       start_addr: 32'h40000000,
								       end_addr:   32'h4000FFFF 
								       },
								  0: '{
								       idx:        32'd0, // Executable SRAM (Boot Space)
								       start_addr: 32'h00000000,
								       end_addr:   32'h0000FFFF // 64KB Exec SRAM
								       }
								  };

   // =========================================================================
   // 7. CPU BFM & PICO INSTANTIATION
   // =========================================================================

   cpu_bfm i_cpu_bfm (
		      .clk_i          ( clk_i   ),
		      .rst_ni         ( rst_ni  ),
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
					.clk         ( clk_i ),
					.resetn      ( rst_ni ),
					.cpu_trap    ( /* connect to a top-level pin or monitor */ ),
					//.axi_req_o   ( slv_reqs[3] ),
					//.axi_resp_i  ( slv_resps[3] )
					.axi_req_o   (  ),
					.axi_resp_i  (  )
					);

   // =========================================================================
   // 8. XBAR CONFIG (Expanded for 4x4 Interconnect)
   // =========================================================================

   localparam		   axi_pkg::xbar_cfg_t XbarCfg = '{
							   NoSlvPorts:         32'd4,
							   NoMstPorts:         32'd4, // Expanded to 4
							   MaxMstTrans:        32'd8,
							   MaxSlvTrans:        32'd8,
							   FallThrough:        1'b1,
							   LatencyMode:        axi_pkg::NO_LATENCY,
							   AxiIdWidthSlvPorts: 4,
							   AxiIdUsedSlvPorts:  4,
							   AxiAddrWidth:       32,
							   AxiDataWidth:       64,
							   NoAddrRules:        32'd4, // Expanded to 4
							   UniqueIds:          1'b0,
							   PipelineStages:     0
							   };

   // Rows = Requesting Masters (4), Columns = Targets (4) -> [Target 3, Target 2, Target 1, Target 0]
   localparam bit [3:0][3:0] XbarConnectivity = '{
						  '{1'b1, 1'b1, 1'b1, 1'b1}, // Port 3: CPU_S (PicoRV32) sees Exec RAM, NPU Cfg, Sampler Cfg, Data RAM
						  '{1'b1, 1'b1, 1'b1, 1'b1}, // Port 2: Data Sampler (DMA) ONLY sees Data RAM (Target 3)
						  '{1'b1, 1'b1, 1'b1, 1'b1}, // Port 1: NPU (DMA) ONLY sees Data RAM (Target 3)
						  '{1'b1, 1'b1, 1'b1, 1'b1}  // Port 0: CPU_L (BFM) sees everything for debugging/testing
						  };

   // =========================================================================
   // 9. AXI XBAR
   // =========================================================================

   axi_xbar #(
	      .Cfg              ( XbarCfg          ),
	      .slv_req_t        ( slv_req_t        ),
	      .slv_resp_t       ( slv_resp_t       ),
	      .mst_req_t        ( mst_req_t        ),
	      .mst_resp_t       ( mst_resp_t       ),
	      .slv_aw_chan_t    ( slv_aw_chan_t    ),
	      .mst_aw_chan_t    ( mst_aw_chan_t    ),
	      .w_chan_t         ( slv_w_chan_t     ),
	      .slv_b_chan_t     ( slv_b_chan_t     ),
	      .mst_b_chan_t     ( mst_b_chan_t     ),
	      .slv_ar_chan_t    ( slv_ar_chan_t    ),
	      .mst_ar_chan_t    ( mst_ar_chan_t    ),
	      .slv_r_chan_t     ( slv_r_chan_t     ),
	      .mst_r_chan_t     ( mst_r_chan_t     ),
	      .rule_t           ( my_xbar_rule_t   ),
	      .Connectivity     ( XbarConnectivity )
	      ) i_xbar (
			.clk_i                  ( clk_i             ),
			.rst_ni                 ( rst_ni            ),
			.test_i                 ( 1'b0              ),

			.slv_ports_req_i        ( xbar_slv_reqs_q   ),
			.slv_ports_resp_o       ( xbar_slv_resps    ),

			.mst_ports_req_o        ( xbar_mst_reqs     ),
			.mst_ports_resp_i       ( xbar_mst_resps    ),

			.addr_map_i             ( xbar_addr_map     ),

			.en_default_mst_port_i ( '0                ), 
			.default_mst_port_i    ( '0                )
			);

   // =========================================================================
   // 10. TARGETS
   // =========================================================================

   // Target 0: Executable SRAM Module
   axi_ram_module #(
		    .AddrWidth ( SocAddrWidth ),
		    .DataWidth ( SocDataWidth ),
		    .IdWidth   ( 8            ),
		    .MemDepth  ( 1024         ),
		    .InitFile  ( "/home/mikail/digital-design/interconnect/axi/Edge-MPSoC/modules/sram_node/firmware.hex" ),
		    .axi_req_t ( mst_req_t    ),
		    .axi_resp_t( mst_resp_t   )
		    ) i_ram_exec_slave_0 (
					  .clk_i      ( clk_i                ),
					  .rst_ni     ( rst_ni               ),
					  .axi_req_i  ( ram_exec_isolated_req    ),
					  .axi_resp_o ( ram_exec_isolated_resp   ),
					  .busy_o     (                      )
					  );

   // Target 1: NPU Co-processor Configuration Port
   npu_wrapper #(
		 .NumMasters      ( 1   ),
		 .axi_cfg_req_t   ( mst_req_t  ),
		 .axi_cfg_resp_t  ( mst_resp_t ),
		 .axi_data_req_t  ( slv_req_t  ),
		 .axi_data_resp_t ( slv_resp_t )
		 ) i_npu_top (
			      .clk_i      ( clk_i                      ),
			      .rst_ni     ( rst_ni                     ),

			      .slv_req_i  ( npu_config_isolated_req    ),
			      .slv_resp_o ( npu_config_isolated_resp   ),

			      .mst_req_o  ( slv_reqs[1]                ),
			      .mst_resp_i ( slv_resps[1]               )
			      );

   // Target 2: New Data Sampler Module Configuration Port
   data_sampler #(
		  .NumMasters      ( 1   ), 
		  .axi_cfg_req_t   ( mst_req_t  ),
		  .axi_cfg_resp_t  ( mst_resp_t ),
		  .axi_data_req_t  ( slv_req_t  ),
		  .axi_data_resp_t ( slv_resp_t )
		  ) i_data_sampler (
				    .clk_i      ( clk_i                      ),
				    .rst_ni     ( rst_ni                     ),

				    .slv_req_i  ( ds_config_isolated_req     ),
				    .slv_resp_o ( ds_config_isolated_resp    ),

				    .mst_req_o  ( slv_reqs[2]                ),
				    .mst_resp_i ( slv_resps[2]               )
				    );

   // Target 3: Data/DMA SRAM Module
   axi_ram_module #(
		    .AddrWidth ( SocAddrWidth ),
		    .DataWidth ( SocDataWidth ),
		    .IdWidth   ( 8            ),
		    .MemDepth  ( 1024         ),
		    .InitFile  ( "/home/mikail/digital-design/interconnect/axi/Edge-MPSoC/modules/sram_node/sram_init.mem" ), // Leaves memory uninitialized
		    .axi_req_t ( mst_req_t    ),
		    .axi_resp_t( mst_resp_t   )
		    ) i_ram_data_slave_3 (
					  .clk_i      ( clk_i                ),
					  .rst_ni     ( rst_ni               ),
					  .axi_req_i  ( ram_data_isolated_req    ),
					  .axi_resp_o ( ram_data_isolated_resp   ),
					  .busy_o     (                      )
					  );

   // ============================================================================
   // SIMULATION-ONLY DEBUG TRACKER & PROTOCOL CHECKER
   // ============================================================================

   initial begin
      $display("\n[SOC_Interconnect_Engine] Ordered Tracking & Protocol Compliance Active.");
   end

   // ----------------------------------------------------------------------------
   // PHASE 1: AXI PROTOCOL COMPLIANCE CHECKS
   // ----------------------------------------------------------------------------
   always @(posedge clk_i) begin
      if (!rst_ni) begin
         for (int i = 0; i < 4; i++) begin 
            if (xbar_slv_reqs_q[i].aw_valid || xbar_slv_reqs_q[i].ar_valid || xbar_slv_reqs_q[i].w_valid) begin
               $error("[AXI PROTOCOL VIOLATION] Slave Port %0d asserted VALID signals during active reset!", i);
            end
         end
         for (int i = 0; i < 4; i++) begin // Updated to 4
            if (xbar_mst_reqs[i].aw_valid || xbar_mst_reqs[i].ar_valid || xbar_mst_reqs[i].w_valid) begin
               $error("[AXI PROTOCOL VIOLATION] XBAR Master Port %0d asserted VALID signals during active reset!", i);
            end
         end
      end

      if (rst_ni && $time > 10000) begin 
         for (int s = 0; s < 4; s++) begin 
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

         for (int m = 0; m < 4; m++) begin // Updated to 4
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
         for (int s = 0; s < 4; s++) begin 
            automatic string initiator = (s == 0) ? "CPU_L" : (s == 3) ? "CPU_S" : $sformatf("PORT_%0d", s);

            if (xbar_slv_reqs_q[s].aw_valid && xbar_slv_resps[s].aw_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [%s WRITE] ---------- SLAVE PORT %0d: WRITE ADDRESS (AW) ----------", $time, initiator, s);
               $display("    AW_ADDR : 0x%8h", xbar_slv_reqs_q[s].aw.addr);
               $display("    AW_ID   : 0x%1h",    xbar_slv_reqs_q[s].aw.id);
            end
            if (xbar_slv_reqs_q[s].w_valid && xbar_slv_resps[s].w_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [%s WRITE] ---------- SLAVE PORT %0d: WRITE DATA (W) -------------", $time, initiator, s);
               $display("    W_DATA  : 0x%16h", xbar_slv_reqs_q[s].w.data);
               $display("    W_LAST  : %1b",        xbar_slv_reqs_q[s].w.last);
            end
            if (xbar_slv_reqs_q[s].ar_valid && xbar_slv_resps[s].ar_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [%s READ] ----------- SLAVE PORT %0d: READ ADDRESS (AR) -----------", $time, initiator, s);
               $display("    AR_ADDR : 0x%8h", xbar_slv_reqs_q[s].ar.addr);
               $display("    AR_ID   : 0x%1h",    xbar_slv_reqs_q[s].ar.id);
            end
         end

         for (int m = 0; m < 4; m++) begin 
            if (xbar_mst_resps[m].b_valid && xbar_mst_reqs[m].b_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [TYPE: WRITE] ---------- MASTER PORT %0d (%s): WRITE RESPONSE (B) --", $time, m, (m == 0) ? "RAM_EXEC" : (m == 1) ? "NPU" : (m == 2) ? "SAMPLER" : "RAM_DATA");
               $display("    B_ID    : 0x%1h",    xbar_mst_resps[m].b.id);
               $display("    B_RESP  : 2'b%2b",   xbar_mst_resps[m].b.resp);
            end
            if (xbar_mst_resps[m].r_valid && xbar_mst_reqs[m].r_ready) begin
               $display("\n>>> [TIME: %0t ps] [INTO XBAR] [TYPE: READ] ----------- MASTER PORT %0d (%s): READ DATA (R) -------", $time, m, (m == 0) ? "RAM_EXEC" : (m == 1) ? "NPU" : (m == 2) ? "SAMPLER" : "RAM_DATA");
               $display("    R_DATA  : 0x%16h", xbar_mst_resps[m].r.data);
               $display("    R_ID    : 0x%1h",    xbar_mst_resps[m].r.id);
               $display("    R_LAST  : %1b",        xbar_mst_resps[m].r.last);
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
               $display("    AW_ADDR : 0x%8h", xbar_mst_reqs[m].aw.addr);
               $display("    AW_ID   : 0x%1h",    xbar_mst_reqs[m].aw.id);
            end
            if (xbar_mst_reqs[m].w_valid && xbar_mst_resps[m].w_ready) begin
               $display("\n<<< [TIME: %0t ps] [OUT OF XBAR] [TYPE: WRITE] --------- MASTER PORT %0d (%s): WRITE DATA (W) ------", $time, m, (m == 0) ? "RAM_EXEC" : (m == 1) ? "NPU" : (m == 2) ? "SAMPLER" : "RAM_DATA");
               $display("    W_DATA  : 0x%16h", xbar_mst_reqs[m].w.data);
               $display("    W_LAST  : %1b",        xbar_mst_reqs[m].w.last);
            end
            if (xbar_mst_reqs[m].ar_valid && xbar_mst_resps[m].ar_ready) begin
               $display("\n<<< [TIME: %0t ps] [OUT OF XBAR] [TYPE: READ] ---------- MASTER PORT %0d (%s): READ ADDRESS (AR) --", $time, m, (m == 0) ? "RAM_EXEC" : (m == 1) ? "NPU" : (m == 2) ? "SAMPLER" : "RAM_DATA");
               $display("    AR_ADDR : 0x%8h", xbar_mst_reqs[m].ar.addr);
               $display("    AR_ID   : 0x%1h",    xbar_mst_reqs[m].ar.id);
            end
         end

         for (int s = 0; s < 4; s++) begin 
            automatic string initiator = (s == 0) ? "CPU_L" : (s == 3) ? "CPU_S" : $sformatf("PORT_%0d", s);

            if (xbar_slv_resps[s].b_valid && xbar_slv_reqs_q[s].b_ready) begin
               $display("\n<<< [TIME: %0t ps] [OUT OF XBAR] [%s WRITE RESP] --------- SLAVE PORT %0d: WRITE RESPONSE (B) ---------", $time, initiator, s);
               $display("    B_ID    : 0x%1h",    xbar_slv_resps[s].b.id);
               $display("    B_RESP  : 2'b%2b",   xbar_slv_resps[s].b.resp);
            end
            if (xbar_slv_resps[s].r_valid && xbar_slv_reqs_q[s].r_ready) begin
               $display("\n<<< [TIME: %0t ps] [OUT OF XBAR] [%s READ RESP] ---------- SLAVE PORT %0d: READ DATA (R) ------------", $time, initiator, s);
               $display("    R_DATA  : 0x%16h", xbar_slv_resps[s].r.data);
               $display("    R_ID    : 0x%1h",    xbar_slv_resps[s].r.id);
               $display("    R_LAST  : %1b",        xbar_slv_resps[s].r.last);
            end
         end
      end
   end


   // ============================================================================
   // SIMULATION 'X' POISONING DETECTOR
   // ============================================================================
   // synopsys translate_off
`ifndef SYNTHESIS
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
      end
   end
`endif
   // synopsys translate_on

   // ============================================================================
   // AXI STALL TRACER
   // ============================================================================
   // synopsys translate_off
`ifndef SYNTHESIS
   always @(posedge clk_i) begin
      // Monitor CPU_L (Port 0)
      if (slv_reqs[0].aw_valid && !slv_resps[0].aw_ready) begin
         $display("[%0t] [STALL TRACE] CPU_L (BFM) is driving AW_VALID=1, but Crossbar AW_READY=0", $time);
         $display("    -> Route to RAM_EXEC  : AW_VALID=%b | AW_READY=%b", mst_reqs[0].aw_valid, mst_resps[0].aw_ready);
         $display("    -> Route to NPU       : AW_VALID=%b | AW_READY=%b", mst_reqs[1].aw_valid, mst_resps[1].aw_ready);
         $display("    -> Route to SAMPLER   : AW_VALID=%b | AW_READY=%b", mst_reqs[2].aw_valid, mst_resps[2].aw_ready);
         $display("    -> Route to RAM_DATA  : AW_VALID=%b | AW_READY=%b", mst_reqs[3].aw_valid, mst_resps[3].aw_ready);
      end
      
      // Monitor CPU_S (Port 3)
      if (slv_reqs[3].aw_valid && !slv_resps[3].aw_ready) begin
         $display("[%0t] [STALL TRACE] CPU_S (PicoRV32) is driving AW_VALID=1, but Crossbar AW_READY=0", $time);
         $display("    -> Route to RAM_EXEC  : AW_VALID=%b | AW_READY=%b", mst_reqs[0].aw_valid, mst_resps[0].aw_ready);
         $display("    -> Route to NPU       : AW_VALID=%b | AW_READY=%b", mst_reqs[1].aw_valid, mst_resps[1].aw_ready);
         $display("    -> Route to SAMPLER   : AW_VALID=%b | AW_READY=%b", mst_reqs[2].aw_valid, mst_resps[2].aw_ready);
         $display("    -> Route to RAM_DATA  : AW_VALID=%b | AW_READY=%b", mst_reqs[3].aw_valid, mst_resps[3].aw_ready);
      end
   end
`endif
   // synopsys translate_on
endmodule
