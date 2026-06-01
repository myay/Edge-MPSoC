// ============================================================================
// Module: data_sampler
// Description:
//    Preliminary empty shell for the Data Sampler module.
//    Adheres to the parameterized AXI configuration and data interfaces.
// ============================================================================

module data_sampler #(
		      parameter int unsigned NumMasters = 1,
		      parameter		     type axi_cfg_req_t = logic,
		      parameter		     type axi_cfg_resp_t = logic,
		      parameter		     type axi_data_req_t = logic,
		      parameter		     type axi_data_resp_t = logic
		      ) (
			 input logic clk_i,
			 input logic rst_ni,

			 // =========================================================================
			 // CONFIGURATION SLAVE PATH (from Interconnect/CPU)
			 // =========================================================================
			 input	     axi_cfg_req_t slv_req_i,
			 output	     axi_cfg_resp_t slv_resp_o,

			 // =========================================================================
			 // DATA MASTER PATH (to Interconnect/RAM)
			 // =========================================================================
			 output	     axi_data_req_t mst_req_o,
			 input	     axi_data_resp_t mst_resp_i
			 );

   // =========================================================================
   // TODO: Instantiate data_sampler_wrapper_regs and axi_dma_wr here
   // =========================================================================

   // Structural tie-offs to prevent X-propagation and compiler warnings 
   // before the actual logic is implemented.
   always_comb begin
      slv_resp_o = '0;
      mst_req_o  = '0;
   end

endmodule
