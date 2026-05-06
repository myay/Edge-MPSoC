`include "axi/typedef.svh"

module soc #(
    // Parameter names changed to avoid global naming collisions
    parameter int unsigned SocAddrWidth = 32,
    parameter int unsigned SocDataWidth = 64,
    parameter int unsigned SocIdWidth   = 4,
    parameter int unsigned SocUserWidth = 1,
    
    // Type Parameters (Passed in from the top-level Testbench)
    parameter type axi_req_t    = logic,
    parameter type axi_resp_t   = logic,
    // Sub-channel types required for Xbar internal member access
    parameter type aw_chan_t    = logic,
    parameter type w_chan_t     = logic,
    parameter type b_chan_t     = logic,
    parameter type ar_chan_t    = logic,
    parameter type r_chan_t     = logic
) (
    input  logic      clk_i,
    input  logic      rst_ni,
    
    // External Master Interface (Exposed for Testbench/CPU BFM)
    input  axi_req_t  ext_mst_req_i,
    output axi_resp_t ext_mst_resp_o
);

    // ---------------------------
    // Internal Wiring
    // ---------------------------
    // Arrays required by the axi_xbar module (NM=1 Master, NS=1 Slave)
    axi_req_t  [0:0] slv_reqs;
    axi_resp_t [0:0] slv_resps;
    axi_req_t  [0:0] mst_reqs;
    axi_resp_t [0:0] mst_resps;

    // Connect the SoC's external ports to the Xbar Slave Port 0
    assign slv_reqs[0]    = ext_mst_req_i;
    assign ext_mst_resp_o = slv_resps[0];

    // ---------------------------
    // 1. CPU Bus Functional Model (BFM)
    // ---------------------------
    // This allows you to call tasks like: i_soc.i_cpu_bfm.axi_write(...)
    // It "listens" to the same response signals the SoC sees.
    cpu_bfm #(
        .AXI_ADDR_WIDTH (SocAddrWidth),
        .AXI_DATA_WIDTH (SocDataWidth),
        .AXI_ID_WIDTH   (SocIdWidth)
    ) i_cpu_bfm (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .ext_mst_req_o  (), // Driven externally via ext_mst_req_i in TB
        .ext_mst_resp_i (ext_mst_resp_o) 
    );

    // ---------------------------
    // 2. AXI Interconnect (Xbar)
    // ---------------------------
    // Define the Address Map (SRAM at 0x0000_0000 - 0x0000_FFFF)
    localparam axi_pkg::xbar_rule_32_t [0:0] AddrTable = '{
        '{
            idx:        32'd0, 
            start_addr: 32'h0000_0000,
            end_addr:   32'h0000_FFFF
        }
    };

    // Configuration struct for the Xbar
    localparam axi_pkg::xbar_cfg_t XbarCfg = '{
        NoSlvPorts:         32'd1,
        NoMstPorts:         32'd1,
        MaxMstTrans:        4,
        MaxSlvTrans:        4,
        FallThrough:        1'b1,
        LatencyMode:        axi_pkg::NO_LATENCY,
        PipelineStages:     0,
        AxiIdWidthSlvPorts: SocIdWidth,
        AxiIdUsedSlvPorts:  SocIdWidth,
        UniqueIds:          1'b0,
        AxiAddrWidth:       SocAddrWidth,
        AxiDataWidth:       SocDataWidth,
        NoAddrRules:        32'd1
    };

    axi_xbar #(
        .Cfg           ( XbarCfg ),
        .ATOPs         ( 1'b0 ), // Disable ATOP filter to bypass Verilator error
        .slv_aw_chan_t ( aw_chan_t ),
        .mst_aw_chan_t ( aw_chan_t ),
        .w_chan_t      ( w_chan_t  ),
        .slv_b_chan_t  ( b_chan_t  ),
        .mst_b_chan_t  ( b_chan_t  ),
        .slv_ar_chan_t ( ar_chan_t ),
        .mst_ar_chan_t ( ar_chan_t ),
        .slv_r_chan_t  ( r_chan_t  ),
        .mst_r_chan_t  ( r_chan_t  ),
        .slv_req_t     ( axi_req_t ),
        .slv_resp_t    ( axi_resp_t ),
        .mst_req_t     ( axi_req_t ),
        .mst_resp_t    ( axi_resp_t ),
        .rule_t        ( axi_pkg::xbar_rule_32_t )
    ) i_xbar (
        .clk_i                  ( clk_i ),
        .rst_ni                 ( rst_ni ),
        .test_i                 ( 1'b0 ),
        .slv_ports_req_i        ( slv_reqs ),
        .slv_ports_resp_o       ( slv_resps ),
        .mst_ports_req_o        ( mst_reqs ),
        .mst_ports_resp_i       ( mst_resps ),
        .addr_map_i             ( AddrTable ),
        .en_default_mst_port_i  ( 1'b0 ),
        .default_mst_port_i     ( '0 )
    );

    // ---------------------------
    // 3. AXI RAM Module (Slave Node)
    // ---------------------------
    axi_ram_module #(
        .AddrWidth ( SocAddrWidth ),
        .DataWidth ( SocDataWidth ),
        .IdWidth   ( SocIdWidth   ),
        .MemDepth  ( 1024         ),
        .axi_req_t ( axi_req_t    ),
        .axi_resp_t( axi_resp_t   )
    ) i_ram_slave_0 (
        .clk_i      ( clk_i ),
        .rst_ni     ( rst_ni ),
        .axi_req_i  ( mst_reqs[0] ),
        .axi_resp_o ( mst_resps[0] ),
        .busy_o     ( ) 
    );

endmodule
