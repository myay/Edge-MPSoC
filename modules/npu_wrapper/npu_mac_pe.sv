// ============================================================================
//  Module: NPU PE
//  Description:
//      This module implements the NPU processing element (PE) functionality and interfaces with AXI.
//      This module is designed to compute MAC operations and is a part of the NPU core, which is responsible for executing neural network operations.
// ============================================================================

module npu_mac_pe (
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
    // Input Data (weights and data input)
    // =========================================================================

    input   logic [7:0] weights_i,
    input   logic [7:0] dataInput_i

    // =========================================================================
    // Output Data (MAC result)
    // =========================================================================
    output  logic [63:0] mac_result_o

);

    // =========================================================================
    // Implementation of MAC operation
    // =========================================================================
    logic signed [15:0] product;
    assign product = weights_i * dataInput_i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mac_result_o <= '0;
        end else begin
            mac_result_o <= mac_result_o + product; // Accumulate the product into the MAC result
            // mac_result_o <= mac_result_o + {{48{product[15]}}, product}; // If you want to extend the product to 64 bits
        end
    end
endmodule