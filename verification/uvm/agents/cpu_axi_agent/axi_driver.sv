// The driver is the only component that interacts with vif
// It pulls transactions from the sequencer and translates them into physical calls on the virtual interface
// Class is parametrized with axi_transaction
// Extends uvm driver and therefore inherits tools to work with sequences  
class axi_driver extends uvm_driver#(axi_transaction);
   // Registers axi_driver with the UVM Factory, allowing it to be instantiated using axi_driver::type_id::create() and enabling factory overrides
   `uvm_component_utils(axi_driver)

   // Declares a handle for a virtual interface of type cpu_bfm_if
   // Acts as a pointer to the physical SystemVerilog interface connected to the DUT
   virtual cpu_bfm_if vif;

   // Standard UVM component constructor
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // looks up the virtual interface handle named "vif" stored in the UVM configuration database and assigns it to local variable vif
      void'(uvm_config_db#(virtual cpu_bfm_if)::get(this, "", "vif", vif));
   endfunction

   virtual task run_phase(uvm_phase phase);
      forever begin
	 // blocks execution until the sequencer delivers a transaction, then populates the handle req with that transaction's memory reference
         seq_item_port.get_next_item(req);
         
         if (req.cmd == AXI_WRITE) begin
	    // Drive pins of DUT
            vif.axi_write(req.addr, req.data);
         end else if (req.cmd == AXI_READ) begin
            vif.axi_read(req.addr, req.data); // Updates req.data with read value
         end
	 // Tells the sequencer that the driver has finished executing the item, unblocking the sequence's finish_item() call
         seq_item_port.item_done();
      end
   endtask
endclass
