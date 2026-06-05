module cpu_picorv32_axi (
			 input logic	     clk,
			 input logic	     resetn, // PicoRV32 uses active-low reset
			 output logic	     cpu_trap,

			 // Master AXI4-Lite Interface to your Central Interconnect
			 output logic [31:0] axi_awaddr,
			 output logic	     axi_awvalid,
			 input logic	     axi_awready,

			 output logic [31:0] axi_wdata,
			 output logic [3:0]  axi_wstrb,
			 output logic	     axi_wvalid,
			 input logic	     axi_wready,

			 input logic [1:0]   axi_bresp, // Interconnect drives this, but Pico ignores it
			 input logic	     axi_bvalid,
			 output logic	     axi_bready,

			 output logic [31:0] axi_araddr,
			 output logic	     axi_arvalid,
			 input logic	     axi_arready,

			 input logic [31:0]  axi_rdata,
			 input logic [1:0]   axi_rresp, // Interconnect drives this, but Pico ignores it
			 input logic	     axi_rvalid,
			 output logic	     axi_rready
			 );

   // Instantiate the AXI-wrapped Pico Core
   picorv32_axi #(
		  .PROGADDR_RESET(32'h0000_0000), // Base address where firmware sits
		  .ENABLE_COUNTERS(0),            // Disable performance counters for simulation speed
		  .ENABLE_MUL(0),                 // Disable hardware multiplier for now
		  .ENABLE_DIV(0),                 // Disable hardware divider for now
		  .BARREL_SHIFTER(1)              // Leave barrel shifter enabled for standard C code shifts
		  ) u_pico_cpu (
				.clk             (clk),
				.resetn          (resetn),
				.trap            (cpu_trap),
				
				// AXI Write Address Channel
				.mem_axi_awvalid (axi_awvalid),
				.mem_axi_awready (axi_awready),
				.mem_axi_awaddr  (axi_awaddr),
				.mem_axi_awprot  (), // Core outputs this, but wrapper doesn't use it. Float.
				
				// AXI Write Data Channel
				.mem_axi_wvalid  (axi_wvalid),
				.mem_axi_wready  (axi_wready),
				.mem_axi_wdata   (axi_wdata),
				.mem_axi_wstrb   (axi_wstrb),
				
				// AXI Write Response Channel
				.mem_axi_bvalid  (axi_bvalid),
				.mem_axi_bready  (axi_bready),
				// (No .mem_axi_bresp port exists on PicoRV32)
				
				// AXI Read Address Channel
				.mem_axi_arvalid (axi_arvalid),
				.mem_axi_arready (axi_arready),
				.mem_axi_araddr  (axi_araddr),
				.mem_axi_arprot  (), // Core outputs this, but wrapper doesn't use it. Float.
				
				// AXI Read Data Channel
				.mem_axi_rvalid  (axi_rvalid),
				.mem_axi_rready  (axi_rready),
				.mem_axi_rdata   (axi_rdata),
				// (No .mem_axi_rresp port exists on PicoRV32)

				// ----------------------------------------------------------------
				// TIE-OFFS: Ensure unused PicoRV32 inputs don't become 'X'
				// ----------------------------------------------------------------
				// Pico Co-Processor Interface (PCPI)
				.pcpi_valid      (),
				.pcpi_insn       (),
				.pcpi_rs1        (),
				.pcpi_rs2        (),
				.pcpi_wr         (1'b0),
				.pcpi_rd         (32'b0),
				.pcpi_wait       (1'b0),
				.pcpi_ready      (1'b0),

				// IRQ interface
				.irq             (32'b0),
				.eoi             (),

				// Trace Interface
				.trace_valid     (),
				.trace_data      ()
				);

endmodule
