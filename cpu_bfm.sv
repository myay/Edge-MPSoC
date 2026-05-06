// cpu_bfm.sv
`include "axi_typedefs.svh"

module cpu_bfm (
    input  logic  clk_i,
    input  logic  rst_ni,
    output req_t  ext_mst_req_o,
    input  resp_t ext_mst_resp_i
);

    req_t req;
    assign ext_mst_req_o = req;

    initial begin
        req = '0;
        // This will now work because req_t is explicitly defined in this file
        req.b_ready = 1'b1; 
        req.r_ready = 1'b1;
    end

    task automatic axi_write(
        input logic [TB_ADDR_W-1:0] addr,
        input logic [TB_DATA_W-1:0] data
    );
        @(posedge clk_i);
        req.aw.addr  = addr;
        req.aw_valid = 1'b1;
        req.w.data   = data;
        req.w.strb   = '1;
        req.w.last   = 1'b1;
        req.w_valid  = 1'b1;

        wait (ext_mst_resp_i.aw_ready && ext_mst_resp_i.w_ready);
        @(posedge clk_i);
        req.aw_valid = 1'b0;
        req.w_valid  = 1'b0;
    endtask
endmodule
