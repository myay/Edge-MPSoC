# STA only checks what we describe to it; a path without a constraint isn't "passing", it simply isn't checked
# Two important commands (run on the synthesized design, once without and once with these constraints)
# report_clocks
# check_timing -verbose

# check_timing should report:
# no_clock: the SPI registers have no clock, because spi_sclk_i isn't declared
# no_input_delay / no_output_delay: the I/O ports have no timing
# unconstrained_internal_endpoints: registers nobody checks

# A clock definition gives STA a period and a source
# Every flip-flop clocked from that source gets setup and hold checks

## Primary clocks with create_clock
# 100 MHz
create_clock -period 10.000 -name sys_clk [get_ports clk_i]
# 50 MHz -> this clock comes from outside from the SPI master
# Some components are directly clocked by it
# clocks through logic (LUTs) are actually bad practice on FPGAs,they add skew and use fabric routing instead of the clock network
# This design comes from ASIC RTL, where an inverter and a mux are proper clock tree cells
# There are FPGA-primities for such components as well (possible task: find and replace for FPGA)
create_clock -period 20.000 -name spi_sclk [get_ports spi_sclk_i]

## Clock muxes and set_case_analysis
# A clock mux lets two clocks reach the same registers
# STA times all combinations unless we tell it which one is functional
# test_mode_i selects between the inverted SCLK (normal operation) and the non-inverted SCLK (scan/test mode)
# the statement below tells STA that this signal is constant 0, so only the functional clock path is timed
set_case_analysis 0 [get_ports test_mode_i]
# the statement below says the pin itself has no timing requirement, it's static, set once, before the chip runs
# In general, set_false_path is a timing constraint command (SDC) that tells synthesis and Static Timing Analysis (STA) tools to ignore setup and hold timing checks on specific paths
# You should only use set_false_path on paths where timing genuinely does not matter for normal operation
# (already covered by set_clock_groups above; kept to document the intent)
# Note: Every false path needs a written justification; if you can't write it, the constraint is probably wrong
set_false_path -from [get_ports test_mode_i]

## Clock domain crossings
# sys_clk and spi_sclk are asynchronous; they come from different sources and have no fixed phase relationship
# Vivado assumes all clocks are related and times sys_clk to spi_sclk paths with a requirement calculated from the two periods
# Those checks are meaningless, because the edges can be anywhere relative to each other: We get either fake violations or false confidence
# With the set_clock_groups, STA stops timing every path between the two groups, in both directions. Inside each group, everything is still timed normally
# Note: The constraint doesn't make the crossing safe, it says: The designer guarantees (with a justification) that every signal crossing here is handled by a synchronizer
# Useful commands: report_clock_interaction, report_cdc -details
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks spi_sclk]

## Resets
# An asynchronous reset is also a timing path
# When reset is released, recovery and removal times must be met, the flip-flop equivalent of setup and hold
# rst_ni is assumed to come from a reset synchronizer in sys_clk; that's why it gets an input delay relative to sys_clk
set_input_delay -clock sys_clk 2.000 [get_ports rst_ni]
set_false_path -from [get_ports rst_ni] -to [get_clocks spi_sclk]

## I/O constraints
# STA only knows the inside of the chip
# set_input_delay and set_output_delay describe the outside world: how late the data arrives at the pin, and how early it's needed outside
# max for setup, min for hold
# Input -max = latest arrival (the external device's clock-to-output time plus board delay)
# Output -max = the external device's setup time plus board delay
# The 4 ns are budgets; real values come from the SPI master datasheet and the board
set_input_delay  -clock spi_sclk -max 4.000 [get_ports {spi_cs_i spi_sdi*_i}]
set_input_delay  -clock spi_sclk -min 0.000 [get_ports {spi_cs_i spi_sdi*_i}]
set_output_delay -clock spi_sclk -max 4.000 [get_ports {spi_sdo*_o spi_mode_o*}]
set_output_delay -clock spi_sclk -min 0.000 [get_ports {spi_sdo*_o spi_mode_o*}]
set_false_path -to [get_ports cpu_trap_o]   ;# no timing requirement
