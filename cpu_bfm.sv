`include "axi/typedef.svh"

module cpu_bfm #(
    // Add these missing parameters:
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned AXI_DATA_WIDTH = 64,
    parameter int unsigned AXI_ID_WIDTH   = 4,
    // Keep your existing type parameters:
    parameter type axi_req_t  = logic,
    parameter type axi_resp_t = logic
) (
    input  logic      clk_i,
    input  logic      rst_ni,
    
    // Exposed AXI Interface
    output axi_req_t  ext_mst_req_o,
    input  axi_resp_t ext_mst_resp_i
);

    // Internal state register
    axi_req_t req;
    assign ext_mst_req_o = req;

    initial begin
        req = '0;
        req.b_ready = 1'b1; 
        req.r_ready = 1'b1;
    end

    // --- Write Task ---
    task automatic axi_write(
        input logic [31:0] addr,
        input logic [63:0] data
    );
        @(posedge clk_i);
        req.aw.addr  = addr;
        req.aw_valid = 1'b1;
        req.w.data   = data;
        req.w.strb   = '1;
        req.w.last   = 1'b1;
        req.w_valid  = 1'b1;

        fork
            wait (ext_mst_resp_i.aw_ready);
            wait (ext_mst_resp_i.w_ready);
        join
        
        @(posedge clk_i);
        req.aw_valid = 1'b0;
        req.w_valid  = 1'b0;
        wait (ext_mst_resp_i.b_valid);
        $display("[CPU BFM] Write to %h done", addr);
    endtask

    // --- Read Task ---
    task automatic axi_read(
        input  logic [31:0] addr,
        output logic [63:0] data_o
    );
        @(posedge clk_i);
        req.ar.addr  = addr;
        req.ar_valid = 1'b1;
        wait (ext_mst_resp_i.ar_ready);
        @(posedge clk_i);
        req.ar_valid = 1'b0;
        wait (ext_mst_resp_i.r_valid);
        data_o = ext_mst_resp_i.r.data;
    endtask

endmodule
