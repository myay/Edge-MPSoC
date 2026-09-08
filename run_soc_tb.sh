#!/bin/bash

rm -rf obj_dir

# Set PULP_AXI_PATH if not already set in the environment
#export PULP_AXI_PATH="${PULP_AXI_PATH:-$(cd .. && pwd)}"
export PULP_AXI_PATH="/home/mikail/digital-design/interconnect/axi"

tb_top_name=soc_tb
filelist=sources.f

printf "\n\n"
printf "Top module: ${tb_top_name}\n"
printf "File list:  ${filelist}\n\n"
printf "PULP AXI Path: ${PULP_AXI_PATH}\n\n"

verilator --Wno-fatal --binary --trace-fst --timescale 1ns/1ps --assert \
	  config.vlt \
	  --DVM_TRACE_FST=1 \
	  --top-module ${tb_top_name} \
	  -f ${filelist}

cd obj_dir || exit

./V${tb_top_name}

if [ "$1" = "wf" ]; then
    surfer dump.fst &
fi
