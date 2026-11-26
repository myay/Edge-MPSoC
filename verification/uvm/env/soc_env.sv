// This serves as a container that bundles the verification components, the agent and the scoreboard and wires them together
class soc_env extends uvm_env;
   `uvm_component_utils(soc_env)

   // Object handles for sub-components
   axi_agent      axi_agent;
   axi_scoreboard scoreboard;

   // Standard UVM component constructor
   function new(string name = "soc_env", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      
      // Create agent and scoreboard using the UVM factory
      axi_agent  = axi_agent::type_id::create("axi_agent", this);
      scoreboard = axi_scoreboard::type_id::create("scoreboard", this);

      `uvm_info("ENV", "Build phase executed successfully.", UVM_LOW)
   endfunction

   virtual function void connect_phase(uvm_phase phase);
      // Bottom-up wiring after all sub-components have been built
      super.connect_phase(phase);
      
      // Connect monitor analysis port (broadcaster) to the scoreboard's analysis implementation export (receiver)
      axi_agent.monitor.ap.connect(scoreboard.ap_export);
   endfunction
endclass
