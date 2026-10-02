`include "axi/typedef.svh"

module axi_ram_module #(
                         parameter int unsigned	AddrWidth = 32,
                         parameter int unsigned	DataWidth = 64,
                         parameter int unsigned	IdWidth = 8,
                         parameter int unsigned	MemDepth = 1024,
                         parameter	InitFile = "", // <-- Add parameter here
                         parameter type	axi_req_t = logic,
                         parameter type	axi_resp_t = logic
                        ) (
                            input logic	 clk_i,
                            input logic	 rst_ni,
                           // AXI Slave Interface
                            input	 axi_req_t axi_req_i,
                            output	 axi_resp_t axi_resp_o,
                           // Status
                            output logic busy_o
                           );

   // ---------------------------
   // Internal Signals (Bridge to SRAM)
   // ---------------------------
   logic				mem_req;
   logic				mem_gnt;
   logic [AddrWidth-1:0]		mem_addr;
   logic [DataWidth-1:0]		mem_wdata;
   logic [(DataWidth/8)-1:0]		mem_strb;
   logic				mem_we;
   logic				mem_rvalid;
   logic [DataWidth-1:0]		mem_rdata;
   axi_pkg::atop_t           mem_atop;

   // Initialize signals to prevent X propagation at startup
   initial begin
      mem_req    = 1'b0;
      mem_gnt    = 1'b1; // Keeping your grant tied high
      mem_addr   = '0;
      mem_wdata  = '0;
      mem_strb   = '0;
      mem_we     = 1'b0;
      mem_rvalid = 1'b0;
      mem_rdata  = '0;
      mem_atop   = '0;
   end

   assign mem_gnt = 1'b1;
   // ---------------------------
   // AXI to Memory Bridge
   // ---------------------------
   // Translates AXI handshakes into simple SRAM req/gnt/rvalid
   axi_to_mem #(
		.AddrWidth  (AddrWidth),
		.DataWidth  (DataWidth),
		.IdWidth    (IdWidth),
		.NumBanks   (1),
		.axi_req_t  (axi_req_t),
		.axi_resp_t (axi_resp_t)
		) i_bridge (
			    .clk_i          (clk_i),
			    .rst_ni         (rst_ni),
			    .busy_o         (busy_o),
			    .axi_req_i      (axi_req_i),
			    .axi_resp_o     (axi_resp_o),
			    .mem_req_o      (mem_req),
			    .mem_gnt_i      (mem_gnt),
			    .mem_addr_o     (mem_addr),
			    .mem_wdata_o    (mem_wdata),
			    .mem_strb_o     (mem_strb),
			    .mem_atop_o     (mem_atop),
			    .mem_we_o       (mem_we),
			    .mem_rvalid_i   (mem_rvalid),
			    .mem_rdata_i    (mem_rdata)
			    );

   sram_behavioral #(
		     .DataWidth (DataWidth),
		     .MemDepth  (MemDepth),
		     .InitFile  (InitFile) // <-- Pass parameter down here
		     ) i_sram (
			       .clk_i    (clk_i),
			       .rst_ni   (rst_ni),
			       .req_i    (mem_req),
			       .we_i     (mem_we),
			       .addr_i   (mem_addr[11:3]), // Map AXI byte-address to word-index
			       .wdata_i  (mem_wdata),
			       .be_i     (mem_strb),
			       .rvalid_o (mem_rvalid),
			       .rdata_o  (mem_rdata)
			       );
endmodule
