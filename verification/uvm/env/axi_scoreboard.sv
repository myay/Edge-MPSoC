// The scoreboard acts as the self-checking mechanism in your UVM environment
// It receives every transaction broadcast by the monitor, maintains a "golden" internal memory state, and flags any mismatches between expected and actual read data
// 1. Monitor watches the physical bus pins on the interface (vif). When it sees a complete read or write transfer finish on the bus, it packs those signals into an axi_transaction object
// 2. The monitor broadcasts this transaction object using a UVM feature called an Analysis Port (uvm_analysis_port)
// 3. The monitor's analysis port is wired directly to the scoreboard's analysis export (ap_export)
// 4. Whenever the monitor calls analysis_port.write(trans), UVM triggers the scoreboard's write() function, handing it the transaction object
class axi_scoreboard extends uvm_scoreboard;
   `uvm_component_utils(axi_scoreboard)

   // Analysis export (consumer) to receive transactions from the monitor's analysis port (producer)
   // Declares an analysis implementation port
   // axi_transaction is the type of data packet this port accepts
   // axi_scoreboard is "this"
   uvm_analysis_imp #(axi_transaction, axi_scoreboard) ap_export;

   // Golden memory model using an associative array
   // Maps 32-bit addresses (logic [31:0], the key type inside the brackets) to 64-bit data values (logic [63:0]), simulating the DUT's memory storage in software
   // An associative array in SystemVerilog acts like a software hash map or dictionary
   logic [63:0] golden_mem [logic [31:0]];

   // Standard UVM component constructor taking an instance name and parent handle, passing them up to uvm_scoreboard
   function new(string name = "axi_scoreboard", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap_export = new("ap_export", this);
   endfunction

   // The write() function is called automatically whenever the monitor calls ap.write(trans) to receive a transaction
   // Whenever a connected monitor calls analysis_port.write(trans), UVM automatically invokes this function inside the scoreboard, passing the transaction object trans
   virtual function void write(axi_transaction trans);
      // Assuming your cmd enum uses 1 for WRITE and 0 for READ
      if (trans.cmd == 1 /* AXI_WRITE */) begin
         // Update the golden model on an observed write
         golden_mem[trans.addr] = trans.data;
         `uvm_info("SCB_WRITE", $sformatf("Stored in Golden Model: Addr=0x%0h, Data=0x%0h", 
                                          trans.addr, trans.data), UVM_HIGH)
      end
      else if (trans.cmd == 0 /* AXI_READ */) begin
         // Check if the address has been written to previously
         if (golden_mem.exists(trans.addr)) begin
            // Compare observed read data against the golden model
            if (golden_mem[trans.addr] !== trans.data) begin
               `uvm_error("SCB_FAIL", $sformatf("Data Mismatch at Addr=0x%0h! Expected=0x%0h, Actual=0x%0h",
                                                trans.addr, golden_mem[trans.addr], trans.data))
            end else begin
               `uvm_info("SCB_PASS", $sformatf("Data Match at Addr=0x%0h: Data=0x%0h", 
                                               trans.addr, trans.data), UVM_LOW)
            end
         end else begin
            // Warn if reading from an address that was never written to by the testbench
            `uvm_warning("SCB_UNINIT", $sformatf("Read from uninitialized Addr=0x%0h, Actual=0x%0h", 
                                                 trans.addr, trans.data))
         end
      end
   endfunction
endclass
