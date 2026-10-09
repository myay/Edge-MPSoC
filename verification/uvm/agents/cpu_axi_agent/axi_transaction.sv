// Adress, data, and command are encapsulated here into a uvm transaction object
typedef enum { AXI_READ, AXI_WRITE } axi_cmd_e;

// This base inheritance enables this class to be generated inside sequences, sent through sequencers, and driven to hardware interfaces
class axi_transaction extends uvm_sequence_item;
   rand logic [31:0] addr;
   rand logic [63:0] data;
   rand axi_cmd_e    cmd;
   // Note: The rand keyword instructs SystemVerilog's constraint solver to generate random values for this property when .randomize() is called

   // This registers axi_transaction with the UVM Factory so the object can be created dynamically using axi_transaction::type_id::create().
   `uvm_object_utils_begin(axi_transaction)
      // Registers the integer field addr with UVM core methods. The UVM_ALL_ON flag enables automatic implementations for methods like copy(), clone(), compare(), print(), pack(), and unpack()
      `uvm_field_int(addr, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_enum(axi_cmd_e, cmd, UVM_ALL_ON)
   `uvm_object_utils_end

   function new(string name = "axi_transaction");
      super.new(name);
   endfunction
endclass
