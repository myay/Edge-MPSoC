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
      $display("[TB] Starting AXI Write...");
      i_soc.i_cpu_bfm.axi_write(32'h0000_0010, 64'hDEADBEEFCAFEBABE); 
      
      #100; // Small delay between transactions

      // --- Read Phase ---
      $display("[TB] Starting AXI Read...");
      i_soc.i_cpu_bfm.axi_read(32'h0000_0010, read_data);
      
      // Verification
      if (read_data === 64'hDEADBEEFCAFEBABE) begin
         $display("[TB] SUCCESS: Read data matches written data! (%h)", read_data);
      end else begin
         $display("[TB] ERROR: Data mismatch! Expected DEADBEEFCAFEBABE, Got %h", read_data);
      end

      #100;
      $display("[TB] Start read all...");
      // Read the first 128 words (64-bit each) of the SRAM
      i_soc.i_cpu_bfm.read_all(32'h0000_0000, 64);

      //////
      
      # 1000;
      $display("[TB] Starting NPU rmda...");
      // Trigger a read from NPU, source is SRAM
      i_soc.i_npu_top.rdma_valid_internal = 1'b1;
      
      //#100;
      // wait dynamically until DMA signals it is ready tp accept the command
      do begin
         @(posedge clk);
      end while (!i_soc.i_npu_top.i_axi_dma_rd.s_axis_read_desc_ready);
      //@(posedge clk);
      i_soc.i_npu_top.rdma_valid_internal = 1'b0;

      // Note: Because valid is high for exactly the single clock cycle where ready was also high, the Forencich DMA will consume exactly one descriptor command. It won't see a lingering high signal on the next cycle
      $display("[TB] End NPU rmda...");

      
      #5000;
      $display("Simulation limit reached. Ending...");
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
		  .rst_ni           ( rst_n  ),

		  // 1. Ports for an external Master (NOT used for your SRAM bridge)
		  .ext_mst_req_i    ( '0     ), // Tie to zero if no external master
		  .ext_mst_resp_o   (        ), // Leave open

		  // 2. Ports going to your external Slave (This is your SRAM Bridge)
		  // These use the 'mst' (5-bit ID) types to ensure routing works.
		  .ext_slv_req_o    ( slv_reqs[0]  ), 
		  .ext_slv_resp_i   ( slv_resps[0] )
		  );

   // debug wires
   // --- AXI Side (Bridge Output to Interconnect) ---
   logic				      bridge_axi_rvalid;
   logic [63:0]				      bridge_axi_rdata;
   assign bridge_axi_rvalid = i_soc.i_ram_slave_0.i_bridge.axi_resp_o.r_valid;
   assign bridge_axi_rdata  = i_soc.i_ram_slave_0.i_bridge.axi_resp_o.r.data;

   // --- SRAM Side (Bridge Input from RAM) ---
   logic				      bridge_mem_req;    // Did the bridge ask the RAM for data?
   logic				      bridge_mem_rvalid; // Did the RAM give data back to the bridge?
   logic [63:0]				      bridge_mem_rdata;
   assign bridge_mem_req    = i_soc.i_ram_slave_0.i_bridge.mem_req_o;
   assign bridge_mem_rvalid = i_soc.i_ram_slave_0.i_bridge.mem_rvalid_i;
   assign bridge_mem_rdata  = i_soc.i_ram_slave_0.i_bridge.mem_rdata_i;

   // data arriving at the cpu
   logic [63:0] cpu_view_data;
   assign cpu_view_data = i_soc.i_cpu_bfm.ext_mst_resp_i.r.data;
   
   // always @(posedge clk) begin
   //    $display("[WIRE_CHECK @ %0t] AWVALID=%b, AWREADY=%b, WVALID=%b, WREADY=%b, RST_N=%b", 
   // 	       $time, tb_req.aw_valid, tb_resp.aw_ready, tb_req.w_valid, tb_resp.w_ready, rst_n);
   // end

   initial begin : simplified_id_tracker
      $display("[MONITOR] ID Tracking Started: CPU=1, NPU=2");
      forever @(posedge clk) begin
         
         // 1. Track NPU Requests
         if (i_soc.i_npu_top.mst_req_o.ar_valid && i_soc.i_npu_top.mst_resp_i.ar_ready) begin
            $display("[%0t] >> REQ: NPU issued Read with ID=%0h", $time, i_soc.i_npu_top.mst_req_o.ar.id);
         end

         // 2. Track NPU Responses
         if (i_soc.i_npu_top.mst_resp_i.r_valid && i_soc.i_npu_top.mst_req_o.r_ready) begin
            $display("[%0t] << RESP: NPU received Data with ID=%0h", $time, i_soc.i_npu_top.mst_resp_i.r.id);
         end

	 // 3. Track CPU Responses (To see if it's "stealing" NPU data)
         //if (i_soc.cpu_mst_resp.r_valid && i_soc.cpu_mst_req.r_ready) begin
         //   if (i_soc.cpu_mst_resp.r.id == 4'h2) begin
         //      $display("[%0t] !!! ALERT: CPU port just received ID=2 (NPU Data)!", $time);
         //   end
         // end

	 if (i_soc.i_npu_top.mst_resp_i.r_valid && i_soc.i_npu_top.mst_req_o.r_ready) begin
            $display("[%0t] << DATA RECEIVED: ID=%0h | Data=%h | Last=%b", 
                     $time, 
                     i_soc.i_npu_top.mst_resp_i.r.id, 
                     i_soc.i_npu_top.mst_resp_i.r.data,
                     i_soc.i_npu_top.mst_resp_i.r.last);
         end


	 // Check if the Interconnect is trying to give data to the NPU
	 if (i_soc.i_npu_top.mst_resp_i.r_valid) begin
            if (i_soc.i_npu_top.mst_req_o.r_ready) begin
               $display("[%0t] [HANDSHAKE] SUCCESS: NPU accepted data.", $time);
            end else begin
               $display("[%0t] [HANDSHAKE] STALL: Xbar has data (RVALID), but NPU is NOT READY (RREADY=0)!", $time);
            end
	 end

	 if (i_soc.i_ram_slave_0.i_bridge.axi_resp_o.r_valid) begin
            $display("[%0t] [BRIDGE] Response Leaving Bridge: RID=%0h, Data=%h", 
                     $time, i_soc.i_ram_slave_0.i_bridge.axi_resp_o.r.id, i_soc.i_ram_slave_0.i_bridge.axi_resp_o.r.data);
	 end
	 
      end
   end
endmodule
