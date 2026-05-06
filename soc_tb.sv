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
  axi_req_t  tb_req;
  axi_resp_t tb_resp;

   soc #(
        .axi_req_t   ( my_axi_req_t     ),
        .axi_resp_t  ( my_axi_resp_t    ),
        .aw_chan_t   ( my_axi_aw_chan_t ),
        .w_chan_t    ( my_axi_w_chan_t  ),
        .b_chan_t    ( my_axi_b_chan_t  ),
        .ar_chan_t   ( my_axi_ar_chan_t ),
        .r_chan_t    ( my_axi_r_chan_t  )
    ) i_soc (
        .clk_i           (clk),
        .rst_ni          (rst_n),
        .ext_mst_req_i   (tb_req),  // TB drives this
        .ext_mst_resp_o  (tb_resp)  // SOC drives this
    );

    initial begin
        // Option A: Direct Control
        tb_req.aw.addr = 32'h100;
        
        // Option B: Use the BFM inside the SoC to do the work for you
        // Since tb_req is connected to the SoC port, the BFM's task 
        // will effectively drive the 'tb_req' signals if you align your wiring.
        i_soc.i_cpu_bfm.axi_write(32'h8, 64'h1234);
    end
endmodule
