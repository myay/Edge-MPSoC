#!/bin/bash

rm -rf obj_dir

# Set PULP_AXI_PATH if not already set in the environment
#export PULP_AXI_PATH="${PULP_AXI_PATH:-$(cd .. && pwd)}"
export PULP_AXI_PATH="/home/mikail/digital-design/interconnect/axi"
export UVM_HOME="/home/mikail/digital-design/uvm/uvm-verilator"

tb_top_name=soc_tb
# tb_top_name=soc_uvm_tb
filelist=sources.f

printf "\n\n"
printf "Top module: ${tb_top_name}\n"
printf "File list:  ${filelist}\n\n"
printf "PULP AXI Path: ${PULP_AXI_PATH}\n\n"
printf "UVM Home: ${UVM_HOME}\n"

verilator \
    --binary \
    --timing \
    --trace-fst \
    --timescale 1ns/1ps \
    --assert \
    -j 0 \
    +define+UVM_NO_DPI \
    -DVM_TRACE_FST=1 \
    -Wno-fatal \
    -Wno-CASTCONST \
    -Wno-CONSTRAINTIGN \
    -Wno-DECLFILENAME \
    -Wno-IMPORTSTAR \
    -Wno-REALCVT \
    -Wno-STMTDLY \
    -Wno-UNDRIVEN \
    -Wno-UNOPTFLAT \
    -Wno-VARHIDDEN \
    -Wno-WIDTH \
    config.vlt \
    --top-module ${tb_top_name} \
    -f ${filelist}

cd obj_dir || exit

./V${tb_top_name}

if [ "$1" = "wf" ]; then
    surfer dump.fst &
fi
