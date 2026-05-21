// axi_typedefs.svh
`ifndef AXI_TYPEDEFS_SVH
`define AXI_TYPEDEFS_SVH

`include "axi/typedef.svh"

// --- Global Widths ---
localparam int unsigned TB_ADDR_W   = 32;
localparam int unsigned TB_DATA_W   = 64;
localparam int unsigned TB_USER_W   = 1;

// ID Widths: 4 bits for Masters, 5 bits for the Interconnect/Bridge
localparam int unsigned TB_ID_W_SLV = 4; 
localparam int unsigned TB_ID_W_MST = 5; // 4 bits + ceil(log2(2 Masters))

// --- 1. Slave-Side Types (CPU/NPU Interface) ---
`AXI_TYPEDEF_ALL(soc_slv, 
                 logic [TB_ADDR_W-1:0], 
                 logic [TB_ID_W_SLV-1:0], 
                 logic [TB_DATA_W-1:0], 
                 logic [(TB_DATA_W/8)-1:0], 
                 logic [TB_USER_W-1:0])

typedef soc_slv_req_t  slv_req_t;
typedef soc_slv_resp_t slv_resp_t;

// --- 2. Master-Side Types (Bus/Bridge Interface) ---
`AXI_TYPEDEF_ALL(soc_mst, 
                 logic [TB_ADDR_W-1:0], 
                 logic [TB_ID_W_MST-1:0], 
                 logic [TB_DATA_W-1:0], 
                 logic [(TB_DATA_W/8)-1:0], 
                 logic [TB_USER_W-1:0])

typedef soc_mst_req_t  mst_req_t;
typedef soc_mst_resp_t mst_resp_t;

// Channel Types for XBAR Parameterization
typedef soc_slv_aw_chan_t slv_aw_chan_t;
typedef soc_slv_ar_chan_t slv_ar_chan_t;
typedef soc_slv_w_chan_t  slv_w_chan_t;
typedef soc_slv_b_chan_t  slv_b_chan_t;
typedef soc_slv_r_chan_t  slv_r_chan_t;

typedef soc_mst_aw_chan_t mst_aw_chan_t;
typedef soc_mst_ar_chan_t mst_ar_chan_t;
typedef soc_mst_b_chan_t  mst_b_chan_t;
typedef soc_mst_r_chan_t  mst_r_chan_t;

// --- 3. AXI lite
`AXI_LITE_TYPEDEF_ALL(
		      my_axil_bus,                             // Prefix name
		      logic [TB_ADDR_W-1:0],                   // Parameterized Address width type
		      logic [TB_DATA_W-1:0],                   // Parameterized Data width type
		      logic [(TB_DATA_W/8)-1:0]                // Parameterized Write Strobe width type
		      )

typedef my_axil_bus_req_t  axi_lite_req_t;
typedef my_axil_bus_resp_t axi_lite_resp_t;

`endif
