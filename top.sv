`timescale 1ns/1ps
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
    #20 rst_n = 1;
    #1000;
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

  logic [NUM_BANKS-1:0] mem_req_o;
  logic [NUM_BANKS-1:0] mem_gnt_i;
  logic [NUM_BANKS-1:0][AXI_ADDR_WIDTH-1:0] mem_addr_o;
  logic [NUM_BANKS-1:0][AXI_DATA_WIDTH-1:0] mem_wdata_o;
  logic [NUM_BANKS-1:0][(AXI_DATA_WIDTH/NUM_BANKS)/8-1:0] mem_strb_o;
  logic [NUM_BANKS-1:0] mem_we_o;
  logic [NUM_BANKS-1:0] mem_rvalid_i;
  logic [NUM_BANKS-1:0][AXI_DATA_WIDTH-1:0] mem_rdata_i;

  // Minimal dummy for axi_pkg::atop_t
  //typedef logic atop_t;
  //atop_t mem_atop_o [NUM_BANKS-1:0];
  typedef axi_pkg::atop_t atop_t;
   
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
    .axi_req_i  (axi_req_i),
    .axi_resp_o (axi_resp_o),
    .mem_req_o  (mem_req_o),
    .mem_gnt_i  (mem_gnt_i),
    .mem_addr_o (mem_addr_o),
    .mem_wdata_o(mem_wdata_o),
    .mem_strb_o (mem_strb_o),
    .mem_atop_o (mem_atop_o),
    .mem_we_o   (mem_we_o),
    .mem_rvalid_i(mem_rvalid_i),
    .mem_rdata_i(mem_rdata_i)
  );

  // ---------------------------
  // Tiny SRAM model (behavioral)
  // ---------------------------
  localparam MEM_DEPTH = 1024;
  logic [AXI_DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

  always_ff @(posedge clk) begin
    mem_rvalid_i <= 0;

    if (mem_req_o[0]) begin
      if (mem_we_o[0]) begin
        mem[mem_addr_o[0][11:3]] <= mem_wdata_o[0]; // write
      end else begin
        mem_rdata_i[0] <= mem[mem_addr_o[0][11:3]]; // read
        mem_rvalid_i[0] <= 1;
      end
    end
  end

  // ---------------------------
  // Minimal stimulus
  // ---------------------------
  initial begin
    axi_req_i.aw_valid = 0;
    axi_req_i.ar_valid = 0;
    axi_req_i.w_valid  = 0;
    axi_req_i.b_ready  = 1;
    axi_req_i.r_ready  = 1;

    // Example: toggle aw_valid after reset
    #30 axi_req_i.aw_valid = 1;
    #20 axi_req_i.aw_valid = 0;

    // Example: toggle w_valid
    #50 axi_req_i.w_valid = 1;
    #10 axi_req_i.w_valid = 0;
  end

endmodule
