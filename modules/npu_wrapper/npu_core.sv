//============================================================================
//  Module: NPU Core
//  Description: 
//      This module implements the NPU core functionality and interfaces with AXI4-Lite.
//      This module is designed to be a part of the NPU wrapper, contains MAC units and other processing elements, and is responsible for executing neural network operations.
// ============================================================================

`include "axi_typedefs.svh"

import axi_pkg::*;
import npu_wrapper_regs_pkg::*;

module npu_core (
    input   logic clk,
    input   logic rst_n,


    // =========================================================================
    // CONFIGURATION SLAVE PATH
    // =========================================================================

    input   axi_cfg_req_t slv_req_i,
    output  axi_cfg_resp_t slv_resp_o,

    // =========================================================================
    // DATA MASTER PATH
    // =========================================================================

    output  axi_data_req_t mst_req_o,
    input   axi_data_resp_t mst_resp_i

    // =========================================================================
    // DMA-AXI Stream Input
    // =========================================================================

    input   logic [63:0] stream_data_i,
    input   logic stream_data_keep_i,
    input   logic stream_data_valid_i,
    output  logic stream_data_ready_o,
    input   logic stream_data_last_i,
    input   logic stream_data_id_i,
    input   logic stream_data_dest_i,
    input   logic stream_data_user_i,

    // =========================================================================
    // DMA-AXI Stream Output
    // =========================================================================

    output  logic [63:0] stream_data_o,
    output  logic stream_data_keep_o,
    output  logic stream_data_valid_o,
    input   logic stream_data_ready_i,
    output  logic stream_data_last_o,
    output  logic stream_data_id_o,
    output  logic stream_data_dest_o,
    output  logic stream_data_user_o


);
    npu_mac_pe i_npu_mac_pe (
        .clk(clk),
        .rst_n(rst_n),
        .slv_req_i(slv_req_i),
        .slv_resp_o(slv_resp_o),
        .mst_req_o(mst_req_o),
        .mst_resp_i(mst_resp_i),
        .weights_i(stream_data_i),
        .dataInput_i(stream_data_i)
    );
endmodule