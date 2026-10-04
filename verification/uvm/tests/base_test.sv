class base_test extends uvm_test;
   `uvm_component_utils(base_test)

   my_env env;

   function new(string name = "base_test", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = my_env::type_id::create("env", this);
   endfunction

   virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      `uvm_info("TEST", "Starting base_test execution under Verilator!", UVM_LOW)
      
      #100ns;
      
      `uvm_info("TEST", "Finishing base_test execution.", UVM_LOW)
      phase.drop_objection(this);
   endtask
endclass
