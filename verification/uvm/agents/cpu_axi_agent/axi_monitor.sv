// sniffs the bus activity (or listens to a passive observation task in the interface), packs the observed data into an axi_transaction, and broadcasts it to the scoreboard.
class axi_monitor extends uvm_monitor;
   `uvm_component_utils(axi_monitor)

   virtual cpu_bfm_if vif;
   
   // Analysis port to broadcast observed transactions to the scoreboard
   uvm_analysis_port#(axi_transaction) ap;

   function new(string name = "axi_monitor", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap = new("ap", this);
      
      if (!uvm_config_db#(virtual cpu_bfm_if)::get(this, "", "vif", vif)) begin
         `uvm_fatal("MON", "Failed to retrieve virtual interface handle 'vif'")
      end
   endfunction

   virtual task run_phase(uvm_phase phase);
      axi_transaction trans;
      
      forever begin
         // Wait for the BFM/Interface to signal a completed transaction.
         // Assuming we add a passive snooping task `wait_for_transfer` to cpu_bfm_if:
         vif.wait_for_transfer(trans_cmd, trans_addr, trans_data);

         // Create a new transaction object
         trans = axi_transaction::type_id::create("trans");
         
         // Populate it with the sniffed data
         trans.cmd  = axi_cmd_e'(trans_cmd);
         trans.addr = trans_addr;
         trans.data = trans_data;

         `uvm_info("MON", $sformatf("Observed %s at Addr: %h, Data: %h", 
				    trans.cmd.name(), trans.addr, trans.data), UVM_HIGH)

         // Broadcast to the scoreboard, calling the write method on that port
	 // The monitor doesn't implement a write() function; instead, it calls a write() method provided by its analysis port to broadcast data out
	 // Scoreboard receives this and calls its own write function
         ap.write(trans);
      end
   endtask
endclass
