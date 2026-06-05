module cpu_picorv32_axi #(
			  parameter		 type axi_req_t = logic, 
			  parameter		 type axi_resp_t = logic, 
			  parameter		 type axi_lite_req_t = logic, 
			  parameter		 type axi_lite_resp_t = logic, 
			  parameter int unsigned AxiDataWidth = 32
			  ) (
			     input logic  clk,
			     input logic  resetn, 
			     output logic cpu_trap,

			     output	  axi_req_t axi_req_o,
			     input	  axi_resp_t axi_resp_i
			     );

   // Internal wires for PicoRV32 core
   logic [31:0]				  pico_awaddr;
   logic				  pico_awvalid;
   logic				  pico_awready;
   logic [31:0]				  pico_wdata;
   logic [3:0]				  pico_wstrb;
   logic				  pico_wvalid;
   logic				  pico_wready;
   logic				  pico_bvalid;
   logic				  pico_bready;
   logic [31:0]				  pico_araddr;
   logic				  pico_arvalid;
   logic				  pico_arready;
   logic [31:0]				  pico_rdata;
   logic				  pico_rvalid;
   logic				  pico_rready;

   // 1. Instantiate the Bare-Metal PicoRV32 Core
   picorv32_axi #(
		  .PROGADDR_RESET(32'h0000_0000), 
		  .ENABLE_COUNTERS(0), .ENABLE_MUL(0), .ENABLE_DIV(0), .BARREL_SHIFTER(1)              
		  ) u_pico_cpu (
				.clk             (clk),
				.resetn          (resetn),
				.trap            (cpu_trap),
				.mem_axi_awvalid (pico_awvalid), .mem_axi_awready (pico_awready), .mem_axi_awaddr  (pico_awaddr), .mem_axi_awprot  (), 
				.mem_axi_wvalid  (pico_wvalid),  .mem_axi_wready  (pico_wready),  .mem_axi_wdata   (pico_wdata),  .mem_axi_wstrb   (pico_wstrb),
				.mem_axi_bvalid  (pico_bvalid),  .mem_axi_bready  (pico_bready),
				.mem_axi_arvalid (pico_arvalid), .mem_axi_arready (pico_arready), .mem_axi_araddr  (pico_araddr), .mem_axi_arprot  (), 
				.mem_axi_rvalid  (pico_rvalid),  .mem_axi_rready  (pico_rready),  .mem_axi_rdata   (pico_rdata),
				.pcpi_valid (), .pcpi_insn (), .pcpi_rs1 (), .pcpi_rs2 (), .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0), .pcpi_ready(1'b0),
				.irq(32'b0), .eoi(), .trace_valid(), .trace_data()
				);

   // 2. Pack pins into PULP AXI4-Lite Structs
   axi_lite_req_t  lite_req;
   axi_lite_resp_t lite_resp;

   always_comb begin
      lite_req = '0; 
      lite_req.aw_valid = pico_awvalid;
      lite_req.aw.addr  = pico_awaddr;
      lite_req.w_valid  = pico_wvalid;
      lite_req.w.data   = pico_wdata;
      lite_req.w.strb   = pico_wstrb;
      lite_req.b_ready  = pico_bready;
      lite_req.ar_valid = pico_arvalid;
      lite_req.ar.addr  = pico_araddr;
      lite_req.r_ready  = pico_rready;
   end

   assign pico_awready = lite_resp.aw_ready;
   assign pico_wready  = lite_resp.w_ready;
   assign pico_bvalid  = lite_resp.b_valid;
   assign pico_arready = lite_resp.ar_ready;
   assign pico_rvalid  = lite_resp.r_valid;
   assign pico_rdata   = lite_resp.r.data;

   // 3. Protocol Converter
   axi_lite_to_axi #(
		     .AxiDataWidth   ( AxiDataWidth ),
		     .req_lite_t     ( axi_lite_req_t ),
		     .resp_lite_t    ( axi_lite_resp_t ),
		     .axi_req_t      ( axi_req_t ),
		     .axi_resp_t     ( axi_resp_t )
		     ) i_pulp_protocol_converter (
						  .slv_req_lite_i  ( lite_req ),
						  .slv_resp_lite_o ( lite_resp ),
						  // Tie off Cache signals to 0 (Non-cacheable)
						  .slv_aw_cache_i  ( 4'b0000 ),
						  .slv_ar_cache_i  ( 4'b0000 ),
						  .mst_req_o       ( axi_req_o ),
						  .mst_resp_i      ( axi_resp_i )
						  );

endmodule
