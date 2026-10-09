class axi_agent extends uvm_agent;
   `uvm_component_utils(axi_agent)

   axi_driver    driver;
   axi_sequencer sequencer;
   axi_monitor   monitor;

   function new(string name = "axi_agent", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      // 1. Monitor is ALWAYS built, regardless of active/passive mode
      monitor = axi_monitor::type_id::create("monitor", this);

      // 2. Driver and Sequencer are ONLY built if the agent is ACTIVE
      if (get_is_active() == UVM_ACTIVE) begin
         driver    = axi_driver::type_id::create("driver", this);
         sequencer = axi_sequencer::type_id::create("sequencer", this);
      end
   endfunction

   virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      
      // Connect the driver's pull port to the sequencer's export
      if (get_is_active() == UVM_ACTIVE) begin
         driver.seq_item_port.connect(sequencer.seq_item_export);
      end
   endfunction
endclass
