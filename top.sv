`timescale 1ns/1ps // unit of time for delay / time precision (resolution of the smallest step the sim takes)
`include "../include/axi/typedef.svh"

module top;

  // ---------------------------
  // Clock / Reset
  // ---------------------------
  logic clk;
  logic rst_n;

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, top);
    rst_n = 0;
    #50 rst_n = 1;
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
  localparam int unsigned AXI_USER_WIDTH = 1;
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
  axi_req_t  axi_req_i;
  axi_resp_t axi_resp_o;
  logic busy_o;

  logic [NUM_BANKS-1:0] mem_req_o; // signal with which bridge tells that it has an axi transaction
  logic [NUM_BANKS-1:0] mem_gnt_i; // using mem_gnt_i, the memory can tell the AXI bus to "Wait"
  logic [NUM_BANKS-1:0][AXI_ADDR_WIDTH-1:0] mem_addr_o; // address to write to or read from in the memory
  logic [NUM_BANKS-1:0][AXI_DATA_WIDTH-1:0] mem_wdata_o; // data to write to memory
  logic [NUM_BANKS-1:0][(AXI_DATA_WIDTH/NUM_BANKS)/8-1:0] mem_strb_o; // used to write single bytes, currently ignored
  logic [NUM_BANKS-1:0] mem_we_o; // write enable
  logic [NUM_BANKS-1:0] mem_rvalid_i; // tells that data on mem_rdata_i is ready to be sampled
  logic [NUM_BANKS-1:0][AXI_DATA_WIDTH-1:0] mem_rdata_i; // carries data from the memory to the bridge

  // Minimal dummy for axi_pkg::atop_t
  //typedef logic atop_t;
  //atop_t mem_atop_o [NUM_BANKS-1:0];
  typedef axi_pkg::atop_t atop_t;
  atop_t [NUM_BANKS-1:0] mem_atop_o;
   
  // ---------------------------
  // Instantiate AXI → Memory bridge
  // ---------------------------
  axi_to_mem #(
    .AddrWidth  (AXI_ADDR_WIDTH),
    .DataWidth  (AXI_DATA_WIDTH),
    .IdWidth    (AXI_ID_WIDTH),
    .NumBanks   (NUM_BANKS),
    .axi_req_t  (axi_req_t),
    .axi_resp_t (axi_resp_t)
  ) i_axi_to_mem (
    .clk_i      (clk),
    .rst_ni     (rst_n),
    .busy_o     (busy_o),
    .axi_req_i  (axi_req_i), // contain the axi4 signal list for req (master to slave)
    .axi_resp_o (axi_resp_o), // axi4 signal list for resp (slave to master)
    .mem_req_o  (mem_req_o),
    .mem_gnt_i  (mem_gnt_i),
    .mem_addr_o (mem_addr_o),
    .mem_wdata_o(mem_wdata_o),
    .mem_strb_o (mem_strb_o),
    .mem_atop_o (mem_atop_o), // axi4 atomic transaction, used to carry atomic transactions from the AXI bus down to the memory (if two CPUs are trying to increment a counter at the same time, they use ATOPs to ensure the counter doesn't get corrupted)
    .mem_we_o   (mem_we_o),
    .mem_rvalid_i(mem_rvalid_i),
    .mem_rdata_i(mem_rdata_i)
  );

  // ---------------------------
  // Xbar Configuration (PULP Struct Matched)
  // ---------------------------
  localparam int unsigned XBAR_NM = 1; // Number of Masters (CPUs/NPUs)
  localparam int unsigned XBAR_NS = 1; // Number of Slaves (Bridges/Memories)

  // 1. Define the Address Routing Rules
  // This maps address ranges to specific Slave Port indexes
  localparam axi_pkg::xbar_rule_32_t [0:0] XbarAddrTable = '{
    '{
      idx:        32'd0,          // Route to Master Port 0 (your SRAM bridge)
      start_addr: 32'h0000_0000,
      end_addr:   32'h0000_FFFF   // 64KB range
    }
  };

  // 2. Define the main Xbar configuration struct
  localparam axi_pkg::xbar_cfg_t XbarCfg = '{
    NoSlvPorts:         XBAR_NM,            // Masters connect to Slave Ports
    NoMstPorts:         XBAR_NS,            // Slaves connect to Master Ports
    MaxMstTrans:        4,                  // Allow some in-flight buffer
    MaxSlvTrans:        4,
    FallThrough:        1'b1,               // Immediate data availability
    LatencyMode:        axi_pkg::NO_LATENCY, 
    PipelineStages:     0,
    AxiIdWidthSlvPorts: AXI_ID_WIDTH,
    AxiIdUsedSlvPorts:  AXI_ID_WIDTH,
    UniqueIds:          1'b0,
    AxiAddrWidth:       AXI_ADDR_WIDTH,
    AxiDataWidth:       AXI_DATA_WIDTH,
    NoAddrRules:        32'd1               // We defined 1 rule above
  };
   
  // ---------------------------
  // Tiny SRAM model (behavioral)
  // ---------------------------
  localparam MEM_DEPTH = 1024;
  logic [AXI_DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];
  
  assign mem_gnt_i = '1; // Memory is always ready to accept a request
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_rvalid_i <= '0;
      mem_rdata_i  <= '0;
    end else begin
      // Simple handshake: rvalid is high for one cycle following a request
      if (mem_req_o[0]) begin
        if (mem_we_o[0]) begin
          // WRITE
          mem[mem_addr_o[0][11:3]] <= mem_wdata_o[0];
          $display("[%0t] SRAM: Writing %h to Addr %h", $time, mem_wdata_o[0], mem_addr_o[0]);
        end else begin
          // READ
          mem_rdata_i[0]  <= mem[mem_addr_o[0][11:3]];
          $display("[%0t] SRAM: Reading %h from Addr %h", $time, mem[mem_addr_o[0][11:3]], mem_addr_o[0]);
        end
        mem_rvalid_i[0] <= 1'b1; // Trigger valid on the cycle after req
      end else begin
        mem_rvalid_i[0] <= 1'b0; // Clear it if no new request
      end
    end
  end

// ---------------------------
  // Stimulus Logic
  // ---------------------------
  initial begin
    // Initialize signals
    axi_req_i = '0;           // Clear all bits in the struct
    axi_req_i.b_ready = 1'b1; // Always ready for write responses
    axi_req_i.r_ready = 1'b1; // Always ready for read data
    //mem_gnt_i = '1;           // Memory is always ready to grant
    axi_req_i.aw.prot = 3'b010; // Unprivileged, Non-secure, Data
    axi_req_i.ar.prot = 3'b010;

    axi_req_i.aw.burst = 2'b01; 
    axi_req_i.aw.cache = 4'b0011;
    axi_req_i.aw.prot  = 3'b000;
    
    axi_req_i.ar.burst = 2'b01;
    axi_req_i.ar.cache = 4'b0011;
    axi_req_i.ar.prot  = 3'b010; 
     
    // Wait for reset to de-assert
    @(posedge rst_n);
    repeat (5) @(posedge clk);
    #1; // Step away from the edge

    // --- STEP 1: WRITE DATA ---
    $display("[%0t] Starting Write Transaction...", $time);
    
    // Drive address (AW)
    axi_req_i.aw.addr = 32'h0000_0008;
    axi_req_i.aw.len  = 8'd0;       // Single beat (burst length = 1)
    axi_req_i.aw.size = 3'b011;     // 8 bytes (64-bit)
    axi_req_i.aw_valid = 1'b1;

    // Wait a few cycles before driving data
    repeat (2) @(posedge clk);
    #1;
     
    // Drive data (W) 
    axi_req_i.w.data  = 64'hDEADBEEFCAFEBABE;
    axi_req_i.w.strb  = '1;         // Write all bytes
    axi_req_i.w.last  = 1'b1;       // Last beat of burst
    axi_req_i.w_valid = 1'b1; 

    $display("[%0t] Master AW_VALID=%b, W_VALID=%b", $time, axi_req_i.aw_valid, axi_req_i.w_valid);
    $display("[%0t] Bridge AW_READY=%b, W_READY=%b", $time, axi_resp_o.aw_ready, axi_resp_o.w_ready);
    // Wait for AW and W handshakes

    fork
      @(posedge clk iff axi_resp_o.aw_ready);
      @(posedge clk iff axi_resp_o.w_ready);
    join
    #1; // Delay slightly to satisfy hold time
    axi_req_i.aw_valid = 1'b0;
    axi_req_i.w_valid  = 1'b0;

    // Wait for Write Response (B)
    wait (axi_resp_o.b_valid);
    $display("[%0t] Write Finished!", $time);
    repeat (2) @(posedge clk);


    // --- STEP 2: READ DATA ---
    $display("[%0t] Starting Read Transaction...", $time);
    
    axi_req_i.ar.addr = 32'h0000_0008; // Read the same address
    axi_req_i.ar.len  = 8'd0;
    axi_req_i.ar.size = 3'b011;
    axi_req_i.ar_valid = 1'b1;

    // Wait for AR handshake
    wait (axi_resp_o.ar_ready);
    @(posedge clk);
    axi_req_i.ar_valid = 1'b0;

    // Wait for Read Data (R)
    wait (axi_resp_o.r_valid);
    $display("[%0t] Read Data Received: %h", $time, axi_resp_o.r.data);
    
    if (axi_resp_o.r.data === 64'hDEADBEEFCAFEBABE)
      $display("SUCCESS: Data matches!");
    else
      $display("ERROR: Data mismatch!");

    repeat (10) @(posedge clk);
    $finish;
  end
endmodule
