module sram_behavioral #(
			 parameter int unsigned	DataWidth = 64,
			 parameter int unsigned	MemDepth = 1024,
			 parameter int unsigned	AddrWidth = $clog2(MemDepth)
			 )(
			   input logic			 clk_i,
			   input logic			 rst_ni,

			   input logic			 req_i,
			   input logic			 we_i,
			   input logic [AddrWidth-1:0]	 addr_i,
			   input logic [DataWidth-1:0]	 wdata_i,
			   input logic [DataWidth/8-1:0] be_i,

			   output logic			 rvalid_o,
			   output logic [DataWidth-1:0]	 rdata_o
			   );

   // =========================================================================
   // MEMORY ARRAY
   // =========================================================================

   logic [DataWidth-1:0]				 mem [MemDepth];

   // =========================================================================
   // INIT
   // =========================================================================

   initial begin
      $readmemh(
		"/home/mikail/digital-design/interconnect/axi/own_axi_interconnect/modules/sram_node/sram_init.mem",
		mem
		);
   end

   // =========================================================================
   // SRAM MODEL
   // =========================================================================

   always_ff @(posedge clk_i or negedge rst_ni) begin

      if (!rst_ni) begin
         rvalid_o <= 1'b0;
         rdata_o  <= '0;
      end
      else begin

         // -------------------------------------------------------------
         // Default: No valid response unless a request was processed
         // -------------------------------------------------------------
         rvalid_o <= 1'b0;

         // -------------------------------------------------------------
         // Accept NEW request every cycle
         // -------------------------------------------------------------
         if (req_i) begin

            // Assert valid on the very next cycle
            rvalid_o <= 1'b1;

            // ---------------------------------------------------------
            // WRITE
            // ---------------------------------------------------------
            if (we_i) begin
               for (int i = 0; i < DataWidth/8; i++) begin
                  if (be_i[i]) begin
                     mem[addr_i][8*i +: 8] <= wdata_i[8*i +: 8];
                  end
               end
            end
            
            // ---------------------------------------------------------
            // READ
            // ---------------------------------------------------------
            else begin
               rdata_o <= mem[addr_i];
            end

         end
      end
   end
endmodule
