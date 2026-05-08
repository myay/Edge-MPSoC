#!/bin/bash

rm -rf obj_dir

tb_top_name=soc_tb
filelist=sources.f

printf "\n\n"
printf "Top module: ${tb_top_name}\n"
printf "File list:  ${filelist}\n\n"

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
