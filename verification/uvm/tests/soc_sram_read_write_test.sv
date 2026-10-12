class soc_sram_read_write_test extends base_test;
   `uvm_component_utils(soc_sram_read_write_test)

   function new(string name = "soc_sram_read_write_test", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
   endfunction

   virtual task run_phase(uvm_phase phase);
      soc_write_read_seq seq;

      phase.raise_objection(this);
      `uvm_info(get_type_name(), "[TEST] Starting SRAM Read/Write Test execution...", UVM_LOW)

      // Create and start the write/read sequence
      seq = soc_write_read_seq::type_id::create("seq");
      
      if (!seq.randomize()) begin
         `uvm_fatal(get_type_name(), "Failed to randomize soc_write_read_seq!")
      end

      // Note: Adjust 'env.axi_agent.sequencer' to match your actual instance names in my_env.sv
      seq.start(env.axi_agent.sequencer);

      #2000; // Allow time for final transactions to drain/complete
      `uvm_info(get_type_name(), "[TEST] SRAM Read/Write Test completed successfully.", UVM_LOW)
      phase.drop_objection(this);
   endtask

endclass
