// Acts as a container, hold all verification components
class my_env extends uvm_env;
   `uvm_component_utils(my_env)

   function new(string name = "my_env", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      `uvm_info("ENV", "Build phase executed successfully.", UVM_LOW)
   endfunction
endclass
