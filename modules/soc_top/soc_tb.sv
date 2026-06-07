`timescale 1ns/1ps // unit of time for delay / time precision (resolution of the smallest step the sim takes)
`include "../include/axi/typedef.svh"

module soc_tb;

   // ---------------------------
   // Clock / Reset
   // ---------------------------
   logic clk;
   logic rst_n;

   initial clk = 0;
   always #5 clk = ~clk;

   logic [63:0]	read_data; // Variable to store the result

   initial begin
      $dumpfile("dump.fst");
      $dumpvars(0, soc_tb); // Make sure this matches your TB module name
      rst_n = 0;
      #50 rst_n = 1;

      // --- Write Phase ---
      $display(">>>[TB] Starting AXI Write SRAM exec");
      i_soc.i_cpu_bfm.axi_write(32'h0000_00FF, 64'h1EADBEEFCAFEBABE);
      #100;
      $display(">>>[TB] Starting AXI Write SRAM data");
      i_soc.i_cpu_bfm.axi_write(32'h1000_0010, 64'h2EADBEEFCAFEBABE); 
      
      
      #100; // Small delay between transactions

      // --- Read Phase ---
      $display(">>>[TB] Starting AXI Read SRAM exec...");
      i_soc.i_cpu_bfm.axi_read(32'h0000_00FF, read_data);
      
      // Verification
      if (read_data === 64'h1EADBEEFCAFEBABE) begin
         $display(">>>[TB] SUCCESS: Read data matches written data! (%h)", read_data);
      end else begin
         $display("[TB] ERROR: Data mismatch! Expected 1EADBEEFCAFEBABE, Got %h", read_data);
      end

      #100;
      // --- Read Phase ---
      $display(">>>[TB] Starting AXI Read SRAM data...");
      i_soc.i_cpu_bfm.axi_read(32'h1000_0010, read_data);
      
      // Verification
      if (read_data === 64'h2EADBEEFCAFEBABE) begin
         $display(">>>[TB] SUCCESS: Read data matches written data! (%h)", read_data);
      end else begin
         $display("[TB] ERROR: Data mismatch! Expected 2EADBEEFCAFEBABE, Got %h", read_data);
      end

      #100;
      // $display(">>>[TB] Start read all...");
      // Read the first 128 words (64-bit each) of the SRAM
      //i_soc.i_cpu_bfm.read_all(32'h0000_0000, 8);

      //////

      #1000;

      $display(">>>[TB] Starting DS wdma via AXI Bus...");
      i_soc.i_cpu_bfm.axi_write(32'h4001_0000, 64'h0000_0000_1000_00B8);
      i_soc.i_cpu_bfm.axi_write(32'h4001_0004, 64'h0000_0000_0000_0020);
      i_soc.i_cpu_bfm.axi_write(32'h4001_0008, 64'h0000_0000_0000_0001);
      $display(">>>[TB] End DS wdma configuration.");

      /* -----\/----- EXCLUDED -----\/-----
       // Wait for completion by polling the Busy bit
       while (read_reg(REG_WDMA_STATUS) & 0x1) {
       // Wait...
       }
       // Check if it threw an error during the transfer
       uint32_t err = read_reg(REG_WDMA_ERR);
       if (err != 0) {
       printf("DMA AXI Error Code: %d\n", err);
       }
       -----/\----- EXCLUDED -----/\----- */
      
      # 1000;
      $display(">>>[TB] Starting NPU rdma via AXI Bus...");

      // 1. Write the Source SRAM Base Address to REG_RDMA_ADDR (Offset 0x0)
      // Base (32'h0001_0000) + 0x0 = 32'h0001_0000 | Data = 32'h0000_0010
      i_soc.i_cpu_bfm.axi_write(32'h4000_0000, 64'h0000_0000_1000_00B8);

      // 2. Write the transfer length (63 bytes) to REG_RDMA_LEN (Offset 0x4)
      // Base (32'h0001_0000) + 0x4 = 32'h0001_0004 | Data = 20'd63 (32'h0000_003F)
      i_soc.i_cpu_bfm.axi_write(32'h4000_0004, 64'h0000_0000_0000_003F);

      // 3. Kick off the DMA by writing 1 to the valid field in REG_RDMA_CTRL (Offset 0x8)
      // Base (32'h0001_0000) + 0x8 = 32'h0001_0008 | Data = Bit [0] = 1'b1
      //
      // NOTE: Because this field is defined as 'singlepulse' in your RDL, the 
      // hardware internal register logic handles the 1-cycle handshake automatically.
      // It pulses high for exactly 1 cycle when the AXI write transaction completes, 
      // satisfying the Forencich DMA engine command ingestion perfectly.
      i_soc.i_cpu_bfm.axi_write(32'h4000_0008, 64'h0000_0000_0000_0001);
      //i_soc.i_cpu_bfm.axi_write(32'h0001_0008, 64'h0000_0000_0000_0000);
      /// ***temporary
      // $display("[TB] Bypassing AXI to manually force NPU registers...");

      // // Manually force the internal register logic inside the wrapper
      // i_soc.i_npu_top.rdma_addr = 32'h0000_0010;
      // i_soc.i_npu_top.rdma_len  = 20'd63;
      // $display("[TB] Forcing valid 1 (TODO reg needs fix)...");
      // i_soc.i_npu_top.rdma_valid = 1'b1; 
      //  do begin
      //     @(posedge clk);
      //  end while (!i_soc.i_npu_top.i_axi_dma_rd.s_axis_read_desc_ready);

      // $display("[TB] Force complete. Checking for DMA startup...");
      // /// *** temporary
      $display(">>>[TB] End NPU rdma configuration.");

      #1000;
      $display(">>>Simulation limit reached. Ending...");
      $finish;
   end
   // ---------------------------
   // AXI Parameters
   // ---------------------------
   localparam int unsigned AXI_ADDR_WIDTH = 32;
   localparam int unsigned AXI_DATA_WIDTH = 64;
   localparam int unsigned AXI_ID_WIDTH   = 4;
   localparam int unsigned AXI_USER_WIDTH = 4;
   localparam int unsigned NUM_BANKS      = 1;

   // ---------------------------
   // Minimal AXI request/response structs
   // ---------------------------
   // Macro automatically generates a set of packed structs
   `AXI_TYPEDEF_ALL(my_axi, 
                    logic [AXI_ADDR_WIDTH-1:0], 
                    logic [AXI_ID_WIDTH-1:0], 
                    logic [AXI_DATA_WIDTH-1:0], 
                    logic [(AXI_DATA_WIDTH/8)-1:0], 
                    logic [AXI_USER_WIDTH-1:0])

   // 3. Create aliases so your instantiation remains clean
   typedef my_axi_req_t  axi_req_t; // contains master to slave signals
   typedef my_axi_resp_t axi_resp_t; // slace to master signals

   // ---------------------------
   // Signals
   // ---------------------------
   // Define the req/resp arrays using the NEW mst_req_t types
   mst_req_t  [0:0] slv_reqs;  // Output from SoC to Memory
   mst_resp_t [0:0] slv_resps; // Input from Memory to SoC

   soc #(
         .SocAddrWidth ( AXI_ADDR_WIDTH ),
         .SocDataWidth ( AXI_DATA_WIDTH ),
         .SocIdWidth   ( AXI_ID_WIDTH   ) 
	 ) i_soc (
		  .clk_i            ( clk    ),
		  .rst_ni           ( rst_n  )
		  );

   // debug wires
   // --- AXI Side (Bridge Output to Interconnect) ---
   logic				      bridge_axi_rvalid;
   logic [63:0]				      bridge_axi_rdata;
   assign bridge_axi_rvalid = i_soc.i_ram_exec_slave_0.i_bridge.axi_resp_o.r_valid;
   assign bridge_axi_rdata  = i_soc.i_ram_exec_slave_0.i_bridge.axi_resp_o.r.data;

   // --- SRAM Side (Bridge Input from RAM) ---
   logic				      bridge_mem_req;    // Did the bridge ask the RAM for data?
   logic				      bridge_mem_rvalid; // Did the RAM give data back to the bridge?
   logic [63:0]				      bridge_mem_rdata;
   assign bridge_mem_req    = i_soc.i_ram_exec_slave_0.i_bridge.mem_req_o;
   assign bridge_mem_rvalid = i_soc.i_ram_exec_slave_0.i_bridge.mem_rvalid_i;
   assign bridge_mem_rdata  = i_soc.i_ram_exec_slave_0.i_bridge.mem_rdata_i;

   // data arriving at the cpu
   logic [63:0]				      cpu_view_data;
   assign cpu_view_data = i_soc.i_cpu_bfm.ext_mst_resp_i.r.data;
endmodule
