// axi_typedefs.svh
`ifndef AXI_TYPEDEFS_SVH
`define AXI_TYPEDEFS_SVH

`include "axi/typedef.svh"

// Define the widths once
localparam int unsigned TB_ADDR_W = 32;
localparam int unsigned TB_DATA_W = 64;
localparam int unsigned TB_ID_W   = 4;
localparam int unsigned TB_USER_W = 1;

`AXI_TYPEDEF_ALL(soc_axi, 
                 logic [TB_ADDR_W-1:0], 
                 logic [TB_ID_W-1:0], 
                 logic [TB_DATA_W-1:0], 
                 logic [(TB_DATA_W/8)-1:0], 
                 logic [TB_USER_W-1:0])

typedef soc_axi_req_t  req_t;
typedef soc_axi_resp_t resp_t;

`endif
