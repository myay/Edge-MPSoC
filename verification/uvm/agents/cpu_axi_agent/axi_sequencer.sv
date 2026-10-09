// The sequencer is a simple pass-through component in standard UVM. It acts as the FIFO buffer and arbiter between your test sequences and the driver.
class axi_sequencer extends uvm_sequencer#(axi_transaction);
   `uvm_component_utils(axi_sequencer)

   function new(string name = "axi_sequencer", uvm_component parent = null);
      super.new(name, parent);
   endfunction
   
   // No additional code is needed here for a standard sequencer.
   // The uvm_sequencer base class provides the TLM export and arbitration logic.
endclass
