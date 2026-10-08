// Declares a new class base_test that inherits from UVM’s base uvm_test class
// This inheritance gives it access to the UVM phase manager, configuration mechanisms, and reporting system
class base_test extends uvm_test;
   // Registers base_test with the UVM Factory, so that UVM can instatiate it based on the string "base test"   
   `uvm_component_utils(base_test)

   // Component handle of structural environment that contains agents, scoreboards, etc.
   my_env env;

   // Standard UVM component constructor
   // Calls the constructor of the parent class (uvm_test), registering the component's place and name in the global UVM hierarchy tree (uvm_root).
   function new(string name = "base_test", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   // Background info: UVM separates simulation into build and run phases to make sure that the testbench hierarchy is constructed before any simulation can begin
   // build: no time passes for building up test components, main purpose is memory allocation and building object tree
   // run: starts simulation
   // building happens from top to bottom: this_test -> env -> agent -> driver, monitor, sequencer
   
   // A virtual function ensures that SystemVerilog calls the method based on the actual object type created in memory, rather than the type of handle used to call it (i.e. object type needs to be looked up)
   virtual function void build_phase(uvm_phase phase);
      // Calls uvm_test::build_phase to execute any base UVM library setup code required by the parent class
      super.build_phase(phase);
      // Instantiates the my_env component using the UVM Factory
      // "env": Sets the string instance name of the environment object
      // this: Passes base_test as the parent component, placing env under base_test in the hierarchy tree (uvm_test_top.env)
      env = my_env::type_id::create("env", this);
   endfunction

   // "task" declares a time-consuming routine (in contrast, "build_phase" does not consume any simulation time)
   // in the run_phase, actual simulation stimulus, driving, monitoring, and checking occur
   virtual task run_phase(uvm_phase phase);
      // Informs the UVM phase manager that this component is doing work and prevents UVM from terminating the run_phase prematurely
      phase.raise_objection(this);
      `uvm_info("TEST", "Starting base_test execution under Verilator!", UVM_LOW)
      // advance simulation time by 100 ns
      #100ns;
      
      `uvm_info("TEST", "Finishing base_test execution.", UVM_LOW)
      // drops the raised objection from above and signals that the test is finished
      phase.drop_objection(this);
   endtask
endclass
