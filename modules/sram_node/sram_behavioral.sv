module sram_behavioral #(
                         parameter int unsigned	DataWidth = 64,
                         parameter int unsigned	MemDepth = 1024,
                         parameter int unsigned	AddrWidth = $clog2(MemDepth),
                         parameter string	InitFile = "" // Default to empty (no load)
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
   // PARAMETERIZED INIT
   // =========================================================================

   generate
      if (InitFile != "") begin : gen_mem_init
         initial begin
            $display("[SRAM_INIT] Loading %s into instance %m", InitFile);
            $readmemh(InitFile, mem);
         end
      end
   endgenerate

   // =========================================================================
   // SRAM MODEL
   // =========================================================================

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         rvalid_o <= 1'b0;
         rdata_o  <= '0;
      end
      else begin
         rvalid_o <= 1'b0;

         if (req_i) begin
            rvalid_o <= 1'b1;

            // WRITE
            if (we_i) begin
               for (int i = 0; i < DataWidth/8; i++) begin
                  if (be_i[i]) begin
                     mem[addr_i][8*i +: 8] <= wdata_i[8*i +: 8];
                  end
               end
            end
            
            // READ
            else begin
               rdata_o <= mem[addr_i];
            end
         end
      end
   end
endmodule
