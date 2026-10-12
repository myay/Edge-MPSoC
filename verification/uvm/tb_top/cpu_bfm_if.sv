// An interface in SystemVerilog is just a container
// For the monitor to see when an address handshake or data transfer finishes, it calls vif.wait_for_transfer()
// That task looks at ext_mst_req.aw_valid and ext_mst_resp.aw_ready
// Without those ports piped into the interface, the monitor would have no way to snoop on the bus traffic
interface cpu_bfm_if(
		     input logic clk,
		     input logic rst_n,

		     // Pass the PULP struct types directly into the interface
		     input	 slv_req_t ext_mst_req,
		     input	 slv_resp_t ext_mst_resp
		     );

   // ---------------------------------------------------------
   // Active Driving Tasks (Used by axi_driver)
   // ---------------------------------------------------------
   task axi_write(input logic [31:0] addr, input logic [63:0] data);
      soc_uvm_tb.i_soc.i_cpu_bfm.axi_write(addr, data);
   endtask

   task axi_read(input logic [31:0] addr, output logic [63:0] data);
      soc_uvm_tb.i_soc.i_cpu_bfm.axi_read(addr, data);
   endtask

   // ---------------------------------------------------------
   // Passive Monitoring Task (used by axi_monitor)
   // ---------------------------------------------------------
   // Sniffs the PULP AXI structs for completed handshakes
   task wait_for_transfer(output int trans_cmd, output logic [31:0] trans_addr, output logic [63:0] trans_data);
      logic [31:0] captured_araddr;
      // fork runs multiple thread blocks in parallel
      fork
         // Thread 1: Sniff Write Completion (AW & W handshaken, plus B response)
	 begin : sniff_write
            logic [31:0] captured_awaddr;
            logic [63:0] captured_wdata;

            // Capture AW and W independently
            fork
               begin
		  wait (ext_mst_req.aw_valid && ext_mst_resp.aw_ready);
		  captured_awaddr = ext_mst_req.aw.addr;
               end
               begin
		  wait (ext_mst_req.w_valid && ext_mst_resp.w_ready);
		  captured_wdata = ext_mst_req.w.data;
               end
            join

            // Wait for write response handshake
            wait (ext_mst_resp.b_valid && ext_mst_req.b_ready);

            trans_cmd  = AXI_WRITE;
            trans_addr = captured_awaddr;
            trans_data = captured_wdata;
	 end
         
         // Thread 2: Sniff Read Completion (AR handshake followed by R handshake)
         begin : sniff_read
            wait (ext_mst_req.ar_valid && ext_mst_resp.ar_ready);
            captured_araddr = ext_mst_req.ar.addr;
            
            wait (ext_mst_resp.r_valid && ext_mst_req.r_ready);
            
            trans_cmd  = AXI_READ;
            trans_addr = captured_araddr;
            trans_data = ext_mst_resp.r.data;
         end
	 // Waits for any one of the forked threads to finish
	 // After execution, immediately jumps past the join_any statement—without waiting for the other threads to finish  
      join_any

      // Kills the losing thread (e.g., if a read finished, this cancels the lingering write-waiting thread) so it doesn't remain active in the background.
      disable fork;
      @(posedge clk);
   endtask

endinterface
