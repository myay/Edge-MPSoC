module sram_behavioral #(
			 parameter int unsigned	DataWidth = 64,
			 parameter int unsigned	MemDepth = 1024,
			 parameter int unsigned	AddrWidth = $clog2(MemDepth)
			 ) (
			    input logic			  clk_i,
			    input logic			  rst_ni,
			    input logic			  req_i,
			    input logic			  we_i,
			    input logic [AddrWidth-1:0]	  addr_i,
			    input logic [DataWidth-1:0]	  wdata_i,
			    input logic [DataWidth/8-1:0] be_i, // Byte enables
			    output logic		  rvalid_o,
			    output logic [DataWidth-1:0]  rdata_o
			    );
   
   logic [DataWidth-1:0]				  mem [MemDepth];

   // initialize SRAM with data from text file
   initial begin
      $readmemh("/home/mikail/digital-design/interconnect/axi/own_axi_interconnect/sram_init.mem", mem);
      #1; // Wait 1ns for the load to settle
      // $display("--- SRAM LOAD CHECK ---");
      // foreach (mem[i]) begin
      // 	 if (mem[i] != 0) begin
      //       $display("Index [%0d] contains: %h", i, mem[i]);
      // 	 end
      // end
      // $display("-----------------------");
   end
   
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         rvalid_o <= 1'b0;
         rdata_o  <= '0;
      end else begin
         if (req_i) begin
            if (we_i) begin
               // Handle byte-masked writes if necessary
               mem[addr_i] <= wdata_i;
            end else begin
               rdata_o <= mem[addr_i];
            end
            rvalid_o <= 1'b1;
         end else begin
            rvalid_o <= 1'b0;
         end
      end
   end
endmodule
