// pulp-specific includes
+incdir+${PULP_AXI_PATH}/src
+incdir+${PULP_AXI_PATH}/include
+incdir+${PULP_AXI_PATH}/common_cells_repo/include
// this repo
+incdir+./include

// uvm
+incdir+$UVM_HOME
+incdir+verification/uvm/
+incdir+verification/uvm/env
+incdir+verification/uvm/tests
+incdir+$UVM_HOME
${UVM_HOME}/uvm_pkg.sv
${UVM_HOME}/dpi/uvm_dpi.cc
      
 // pulp/axi stuff
${PULP_AXI_PATH}/src/axi_pkg.sv
${PULP_AXI_PATH}/common_cells_repo/src/cf_math_pkg.sv
${PULP_AXI_PATH}/common_cells_repo/src/cb_filter_pkg.sv
${PULP_AXI_PATH}/common_cells_repo/src/cdc_reset_ctrlr_pkg.sv
${PULP_AXI_PATH}/common_cells_repo/src/ecc_pkg.sv
${PULP_AXI_PATH}/common_cells_repo/src/addr_decode_dync.sv
${PULP_AXI_PATH}/common_cells_repo/src/addr_decode_napot.sv
${PULP_AXI_PATH}/common_cells_repo/src/addr_decode.sv
${PULP_AXI_PATH}/common_cells_repo/src/binary_to_gray.sv
${PULP_AXI_PATH}/common_cells_repo/src/boxcar.sv
${PULP_AXI_PATH}/common_cells_repo/src/cb_filter.sv
${PULP_AXI_PATH}/common_cells_repo/src/cc_onehot.sv
${PULP_AXI_PATH}/common_cells_repo/src/cdc_2phase_clearable.sv
${PULP_AXI_PATH}/common_cells_repo/src/cdc_2phase.sv
${PULP_AXI_PATH}/common_cells_repo/src/cdc_4phase.sv
${PULP_AXI_PATH}/common_cells_repo/src/cdc_fifo_2phase.sv
${PULP_AXI_PATH}/common_cells_repo/src/cdc_fifo_gray_clearable.sv
${PULP_AXI_PATH}/common_cells_repo/src/cdc_fifo_gray.sv
${PULP_AXI_PATH}/common_cells_repo/src/cdc_reset_ctrlr.sv
${PULP_AXI_PATH}/common_cells_repo/src/clk_int_div_static.sv
${PULP_AXI_PATH}/common_cells_repo/src/clk_int_div.sv
${PULP_AXI_PATH}/common_cells_repo/src/clk_mux_glitch_free.sv
${PULP_AXI_PATH}/common_cells_repo/src/counter.sv
${PULP_AXI_PATH}/common_cells_repo/src/credit_counter.sv
${PULP_AXI_PATH}/common_cells_repo/src/delta_counter.sv
${PULP_AXI_PATH}/common_cells_repo/src/ecc_decode.sv
${PULP_AXI_PATH}/common_cells_repo/src/ecc_encode.sv
${PULP_AXI_PATH}/common_cells_repo/src/edge_detect.sv
${PULP_AXI_PATH}/common_cells_repo/src/edge_propagator_ack.sv
${PULP_AXI_PATH}/common_cells_repo/src/edge_propagator_rx.sv
${PULP_AXI_PATH}/common_cells_repo/src/edge_propagator.sv
${PULP_AXI_PATH}/common_cells_repo/src/edge_propagator_tx.sv
${PULP_AXI_PATH}/common_cells_repo/src/exp_backoff.sv
${PULP_AXI_PATH}/common_cells_repo/src/fall_through_register.sv
${PULP_AXI_PATH}/common_cells_repo/src/fifo_v3.sv
${PULP_AXI_PATH}/common_cells_repo/src/gray_to_binary.sv
${PULP_AXI_PATH}/common_cells_repo/src/heaviside.sv
${PULP_AXI_PATH}/common_cells_repo/src/id_queue.sv
${PULP_AXI_PATH}/common_cells_repo/src/isochronous_4phase_handshake.sv
${PULP_AXI_PATH}/common_cells_repo/src/isochronous_spill_register.sv
${PULP_AXI_PATH}/common_cells_repo/src/lfsr_16bit.sv
${PULP_AXI_PATH}/common_cells_repo/src/lfsr_8bit.sv
${PULP_AXI_PATH}/common_cells_repo/src/lfsr.sv
${PULP_AXI_PATH}/common_cells_repo/src/lossy_valid_to_stream.sv
${PULP_AXI_PATH}/common_cells_repo/src/lzc.sv
${PULP_AXI_PATH}/common_cells_repo/src/max_counter.sv
${PULP_AXI_PATH}/common_cells_repo/src/mem_to_banks_detailed.sv
${PULP_AXI_PATH}/common_cells_repo/src/mem_to_banks.sv
${PULP_AXI_PATH}/common_cells_repo/src/multiaddr_decode.sv
${PULP_AXI_PATH}/common_cells_repo/src/mv_filter.sv
${PULP_AXI_PATH}/common_cells_repo/src/onehot_to_bin.sv
${PULP_AXI_PATH}/common_cells_repo/src/passthrough_stream_fifo.sv
${PULP_AXI_PATH}/common_cells_repo/src/plru_tree.sv
${PULP_AXI_PATH}/common_cells_repo/src/popcount.sv
${PULP_AXI_PATH}/common_cells_repo/src/read.sv
${PULP_AXI_PATH}/common_cells_repo/src/ring_buffer.sv
${PULP_AXI_PATH}/common_cells_repo/src/rr_arb_tree.sv
${PULP_AXI_PATH}/common_cells_repo/src/rstgen_bypass.sv
${PULP_AXI_PATH}/common_cells_repo/src/rstgen.sv
${PULP_AXI_PATH}/common_cells_repo/src/serial_deglitch.sv
${PULP_AXI_PATH}/common_cells_repo/src/shift_reg_gated.sv
${PULP_AXI_PATH}/common_cells_repo/src/shift_reg.sv
${PULP_AXI_PATH}/common_cells_repo/src/spill_register_flushable.sv
${PULP_AXI_PATH}/common_cells_repo/src/spill_register.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_arbiter_flushable.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_arbiter.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_delay.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_demux.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_fifo_optimal_wrap.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_fifo.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_filter.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_fork_dynamic.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_fork.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_intf.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_join_dynamic.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_join.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_mux.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_omega_net.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_register.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_throttle.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_to_mem.sv
${PULP_AXI_PATH}/common_cells_repo/src/stream_xbar.sv
${PULP_AXI_PATH}/common_cells_repo/src/sub_per_hash.sv
${PULP_AXI_PATH}/common_cells_repo/src/sync.sv
${PULP_AXI_PATH}/common_cells_repo/src/sync_wedge.sv
${PULP_AXI_PATH}/common_cells_repo/src/trip_counter.sv
${PULP_AXI_PATH}/common_cells_repo/src/unread.sv      

${PULP_AXI_PATH}/src/axi_lite_lfsr.sv
${PULP_AXI_PATH}/src/axi_interleaved_xbar.sv
${PULP_AXI_PATH}/src/axi_lite_to_apb.sv
${PULP_AXI_PATH}/src/axi_burst_splitter_gran.sv
${PULP_AXI_PATH}/src/axi_throttle.sv
${PULP_AXI_PATH}/src/axi_demux_id_counters.sv
${PULP_AXI_PATH}/src/axi_chan_compare.sv
${PULP_AXI_PATH}/src/axi_to_axi_lite.sv
${PULP_AXI_PATH}/src/axi_bus_compare.sv
${PULP_AXI_PATH}/src/axi_join.sv
${PULP_AXI_PATH}/src/axi_lite_regs.sv
${PULP_AXI_PATH}/src/axi_zero_mem.sv
${PULP_AXI_PATH}/src/axi_cdc_dst.sv
${PULP_AXI_PATH}/src/axi_delayer.sv
${PULP_AXI_PATH}/src/axi_atop_filter.sv
${PULP_AXI_PATH}/src/axi_slave_compare.sv
${PULP_AXI_PATH}/src/axi_fifo.sv
${PULP_AXI_PATH}/src/axi_modify_address.sv
${PULP_AXI_PATH}/src/axi_to_mem.sv
${PULP_AXI_PATH}/src/axi_rw_split.sv
${PULP_AXI_PATH}/src/axi_inval_filter.sv
${PULP_AXI_PATH}/src/axi_lite_xbar.sv
${PULP_AXI_PATH}/src/axi_dumper.sv
${PULP_AXI_PATH}/src/axi_lite_mailbox.sv
${PULP_AXI_PATH}/src/axi_to_mem_split.sv
#${PULP_AXI_PATH}/src/axi_test.sv
${PULP_AXI_PATH}/src/axi_multicut.sv
${PULP_AXI_PATH}/src/axi_dw_upsizer.sv
${PULP_AXI_PATH}/src/axi_lite_join.sv
${PULP_AXI_PATH}/src/axi_lite_from_mem.sv
${PULP_AXI_PATH}/src/axi_cut.sv
${PULP_AXI_PATH}/src/axi_to_detailed_mem.sv
${PULP_AXI_PATH}/src/axi_xbar_unmuxed.sv
${PULP_AXI_PATH}/src/axi_to_mem_interleaved.sv
${PULP_AXI_PATH}/src/axi_id_serialize.sv
${PULP_AXI_PATH}/src/axi_isolate.sv
${PULP_AXI_PATH}/src/axi_burst_unwrap.sv
${PULP_AXI_PATH}/src/axi_id_prepend.sv
${PULP_AXI_PATH}/src/axi_lite_dw_converter.sv
${PULP_AXI_PATH}/src/axi_xp.sv
${PULP_AXI_PATH}/src/axi_dw_converter.sv
${PULP_AXI_PATH}/src/axi_err_slv.sv
${PULP_AXI_PATH}/src/axi_lite_demux.sv
${PULP_AXI_PATH}/src/axi_intf.sv
${PULP_AXI_PATH}/src/axi_cdc.sv
${PULP_AXI_PATH}/src/axi_to_mem_banked.sv
${PULP_AXI_PATH}/src/axi_cdc_src.sv
${PULP_AXI_PATH}/src/axi_fifo_delay_dyn.sv
${PULP_AXI_PATH}/src/axi_demux.sv
${PULP_AXI_PATH}/src/axi_dw_downsizer.sv
${PULP_AXI_PATH}/src/axi_lite_to_axi.sv
${PULP_AXI_PATH}/src/axi_mux.sv
${PULP_AXI_PATH}/src/axi_xbar.sv
${PULP_AXI_PATH}/src/axi_serializer.sv
${PULP_AXI_PATH}/src/axi_sim_mem.sv
${PULP_AXI_PATH}/src/axi_lfsr.sv
${PULP_AXI_PATH}/src/axi_lite_mux.sv
${PULP_AXI_PATH}/src/axi_rw_join.sv
${PULP_AXI_PATH}/src/axi_iw_converter.sv
${PULP_AXI_PATH}/src/axi_burst_splitter.sv
${PULP_AXI_PATH}/src/axi_demux_simple.sv
${PULP_AXI_PATH}/src/axi_id_remap.sv
${PULP_AXI_PATH}/src/axi_from_mem.sv

// npu  
./modules/npu_wrapper/regs/generated/npu_wrapper_regs_pkg.sv   
./modules/npu_wrapper/regs/generated/npu_wrapper_regs.sv
./modules/dma/axi_dma_rd.sv
./modules/npu_wrapper/npu_wrapper.sv 

// data sampler
./modules/data_sampler_wrapper/regs/generated/data_sampler_wrapper_regs_pkg.sv   
./modules/data_sampler_wrapper/regs/generated/data_sampler_wrapper_regs.sv
./modules/dma/axi_dma_wr.sv
./modules/data_sampler_wrapper/data_sampler_wrapper.sv

// sram node      
./modules/sram_node/sram_behavioral.sv
./modules/sram_node/axi_sram_node.sv

// cpu
./modules/cpu_bfm/cpu_bfm.sv
./modules/picorv32/picorv32.v
./modules/picorv32/cpu_picorv32_axi.sv

// spi
./modules/spi/axi_spi_slave.sv
./modules/spi/spi_slave_axi_plug.sv
./modules/spi/spi_slave_cmd_parser.sv
./modules/spi/spi_slave_controller.sv
./modules/spi/spi_slave_dc_fifo.sv
./modules/spi/spi_slave_regs.sv
./modules/spi/spi_slave_rx.sv
./modules/spi/spi_slave_syncro.sv
./modules/spi/spi_slave_tx.sv
// other spi dependencies
./modules/spi/deps/pulp_clock_inverter.sv
./modules/spi/deps/pulp_clock_mux2.sv
./modules/spi/deps/dc_token_ring_fifo_din.v
./modules/spi/deps/dc_token_ring_fifo_dout.v
./modules/spi/deps/dc_token_ring.v
./modules/spi/deps/dc_synchronizer.v
./modules/spi/deps/dc_data_buffer.v
./modules/spi/deps/dc_full_detector.v      
     
// soc
./modules/soc_top/soc.sv
./modules/soc_top/soc_tb.sv

// uvm
verification/uvm/tests/test_pkg.sv
verification/uvm/soc_uvm_tb.sv
