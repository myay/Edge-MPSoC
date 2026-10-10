// Encapsulates the driver, sequencer, and monitor into a single verification component representing an AXI bus interface
class axi_agent extends uvm_agent;
   `uvm_component_utils(axi_agent)

   // Drives stimulus to the physical bus
   axi_driver    driver;
   // Routes sequence items from sequences to the driver
   axi_sequencer sequencer;
   // Captures interface activity and converts it into transaction items for scoreboard
   axi_monitor   monitor;

   // Standard UVM component constructor taking an instance name string (defaulting to "axi_agent") and a parent component handle (defaulting to null) 
   // It passes both up to uvm_agent via super.new()
   function new(string name = "axi_agent", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   // Overrides build_phase to instantiate sub-components top-down during the UVM build execution phase
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      // Build monitor using UVM factory
      monitor = axi_monitor::type_id::create("monitor", this);

      // Driver and Sequencer are only built if the agent is ACTIVE
      // When a UVM agent or driver is configured as "active" (UVM_ACTIVE), it means it actively drives physical signals onto the DUT's bus interface to generate stimulus
      // Active: sequencer + driver + monitor
      // Passive: monitor only
      // UVM sets it to UVM_ACTIVE by default
      // You set an agent as active or passive in a higher-level UVM component—most inside the build_phase() of your Environment (uvm_env) or Test (uvm_test) before the agent's build phase so that it is known whether sequencer and driver need to be instantiated
      // It can be done using uvm_config_db
      //It must be set before the agent's build_phase() executes so the agent knows whether to instantiate the driver and sequencer.
      if (get_is_active() == UVM_ACTIVE) begin
         driver    = axi_driver::type_id::create("driver", this);
         sequencer = axi_sequencer::type_id::create("sequencer", this);
      end
   endfunction

   // Overrides connect_phase to wire up TLM ports and exports bottom-up after all components have been instantiated during build_phase
   virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      
      // Connect the driver's pull port to the sequencer's export
      // This allows the driver to call get_next_item() / item_done() to fetch items from sequences running on the sequencer
      if (get_is_active() == UVM_ACTIVE) begin
         driver.seq_item_port.connect(sequencer.seq_item_export);
      end
   endfunction
endclass
