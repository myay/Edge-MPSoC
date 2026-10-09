// UVM sequence class that generates a sequence of transactions
// Parameterizing with #(axi_transaction) specifies that this sequence generates and manages transactions of type axi_transaction
class soc_write_read_seq extends uvm_sequence#(axi_transaction);
   `uvm_object_utils(soc_write_read_seq)

   function new(string name = "soc_write_read_seq");
      super.new(name);
   endfunction

   // Main task of the sequence
   // UVM automatically executes body() when the sequence is started on a sequencer with seq.start(sequencer)
   virtual task body();
      axi_transaction req;

      // Write Transaction
      // Instantiates a new axi_transaction object via the UVM Factory. Using type_id::create() ensures factory overrides are honored if set up by a test.
      req = axi_transaction::type_id::create("req");
      // Initiates the UVM sequence-driver handshake. It requests access to the sequencer and blocks execution until the sequencer grants arbitration and the driver is ready to accept a transaction.
      start_item(req);
      req.cmd  = AXI_WRITE;
      req.addr = 32'h1000_0010;
      req.data = 64'h2EADBEEFCAFEBABE;
      // Completes the handshake by delivering the populated req item to the driver and waiting until the driver finishes accepting or processing it.
      finish_item(req);

      // Read Transaction
      req = axi_transaction::type_id::create("req");
      // Requests arbitration on the sequencer for the second transaction and blocks until ready.
      start_item(req);
      req.cmd  = AXI_READ;
      req.addr = 32'h1000_0010;
      // Sends the read transaction to the driver and waits for completion.
      finish_item(req);
   endtask
endclass
