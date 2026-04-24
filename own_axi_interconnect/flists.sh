#!/bin/bash

adder_sources=(
	'src/adder/rtl/adder.sv'
	)
adder_tb_path='src/adder/tb/adder_tb.sv'

extend_sources=(
	'src/extend/rtl/extend.sv'
	)
extend_tb_path="src/extend/tb/extend_tb.sv"

extend_dmem_sources=(
	'src/extend_dmem/rtl/extend_dmem.sv'
	)
extend_dmem_tb_path="src/extend_dmem/tb/extend_dmem_tb.sv"

flopr_sources=(
	'src/flopr/rtl/flopr.sv'
	)
flopr_tb_path="src/flopr/tb/flopr_tb.sv"

flopenr_sources=(
	'src/flopenr/rtl/flopenr.sv'
	)
flopenr_tb_path="src/flopenr/tb/flopenr_tb.sv"

mux2_sources=(
	'src/mux2/rtl/mux2.sv'
	)
mux2_tb_path="src/mux2/tb/mux2_tb.sv"

mux3_sources=(
	'src/mux3/rtl/mux3.sv'
	)
mux3_tb_path="src/mux3/tb/mux3_tb.sv"

mux4_sources=(
	'src/mux4/rtl/mux4.sv'
	)
mux4_tb_path="src/mux4/tb/mux4_tb.sv"

regfile_sources=(
	'src/regfile/rtl/regfile.sv'
	)
regfile_tb_path="src/regfile/tb/regfile_tb.sv"

csr_sources=(
	'src/csr/rtl/csr.sv'
	)
csr_tb_path="src/csr/tb/csr_tb.sv"

alu_sources=(
	'src/alu/rtl/alu.sv'
	)
alu_tb_path="src/alu/tb/alu_tb.sv"

datapath_sources=(
	'src/datapath/rtl/datapath.sv'
	)
datapath_sources+=("${adder_sources[@]}")
datapath_sources+=("${extend_sources[@]}")
datapath_sources+=("${flopr_sources[@]}")
datapath_sources+=("${mux2_sources[@]}")
datapath_sources+=("${regfile_sources[@]}")
datapath_sources+=("${csr_sources[@]}")
datapath_sources+=("${alu_sources[@]}")
datapath_sources+=("${mux3_sources[@]}")
datapath_sources+=("${mux4_sources[@]}")
datapath_sources+=("${extend_dmem_sources[@]}")
datapath_tb_path="src/datapath/tb/datapath_tb.sv"

aludec_sources=(
	'src/aludec/rtl/aludec.sv'
	)
aludec_tb_path="src/aludec/tb/aludec_tb.sv"

maindec_sources=(
	'src/maindec/rtl/maindec.sv'
	)
maindec_tb_path="src/maindec/tb/maindec_tb.sv"

controller_sources=(
	'src/controller/rtl/controller.sv'
	)
controller_tb_path="src/controller/tb/controller_tb.sv"
controller_sources+=("${aludec_sources[@]}")
controller_sources+=("${maindec_sources[@]}")

riscvsc_sources=(
	'src/riscvsc/rtl/riscvsc.sv'
	)
riscvsc_tb_path="src/riscvsc/tb/riscvsc_tb.sv"
riscvsc_sources+=("${controller_sources[@]}")
riscvsc_sources+=("${datapath_sources[@]}")

imem_sources=(
	'src/imem/rtl/imem.sv'
	)
imem_tb_path="src/imem/tb/imem_tb.sv"

dmem_sources=(
	'src/dmem/rtl/dmem.sv'
	)
dmem_tb_path="src/dmem/tb/dmem_tb.sv"

dmem_vam_sources=(
	'src/dmem_vam/rtl/dmem_vam.sv'
	)
dmem_vam_tb_path="src/dmem_vam/tb/dmem_vam_tb.sv"

riscvsc_top_sources=(
	'src/riscvsc_top/rtl/riscvsc_top.sv'
	)
riscvsc_top_tb_path="src/riscvsc_top/tb/riscvsc_top_tb.sv"
riscvsc_top_sources+=("${riscvsc_sources[@]}")
riscvsc_top_sources+=("${imem_sources[@]}")
riscvsc_top_sources+=("${dmem_sources[@]}")
riscvsc_top_sources+=("${dmem_vam_sources[@]}")
