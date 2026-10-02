# =============================================================================
# Vivado Automation Script: Project-Based Synthesis & Implementation
# =============================================================================

# run with: vivado -mode batch -source run_synth.tcl

# Anchor paths to boards/test/ and repository root
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize "$script_dir/../../.."]

# Debug output to verify paths in Vivado output
puts "========================================================"
puts "DEBUG PATHS:"
puts "  Script Dir: $script_dir"
puts "  Repo Root:  $repo_root"
puts "========================================================"

# Load common utility scripts
source "$repo_root/fpga/common/utils.tcl"

# Project settings
set proj_name   "test_project"
set top_module  "soc.sv"
set target_part "xc7a35tcsg324-1"

# Output directories (grouped inside boards/test/build/)
set build_dir   "$script_dir/build"
set proj_dir    "$build_dir/project"
set output_dir  "$build_dir/output"

# Source locations
set rtl_dir     "$repo_root/rtl"
set common_dir  "$repo_root/common"
set xdc_file    "$script_dir/constraints/constraints.xdc"

# Create output folders
file mkdir $proj_dir
file mkdir $output_dir

# Close any accidentally open projects just in case
catch {close_project}

# Create the project (Fixes the "No open project" exception)
create_project -force $proj_name $proj_dir -part $target_part

# Import sources via common helper
import_filelist "$repo_root/sources.f"

# Import constraints
read_xdc "$script_dir/constraints/constraints.xdc"

# Set top module
set_property top $top_module [get_filesets sources_1]
update_compile_order -fileset sources_1

# Run Synthesis
puts "--- STARTING SYNTHESIS ---"
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check for synthesis errors
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "ERROR: Synthesis failed!"
}

# Open Synthesis to write reports
open_run synth_1
write_checkpoint -force $output_dir/post_synth.dcp
report_utilization -file $output_dir/post_synth_util.txt

# Run Implementation (Optimize, Place, Route)
puts "--- STARTING IMPLEMENTATION ---"
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1

# Check for implementation errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "ERROR: Implementation failed!"
}

# Open Implementation to extract final reports
open_run impl_1
write_checkpoint -force $output_dir/post_route.dcp
report_timing_summary -file $output_dir/post_route_timing_summary.txt
report_utilization -file $output_dir/post_route_util.txt
report_power -file $output_dir/post_route_power.txt

puts "--- VIVADO FLOW COMPLETED SUCCESSFULLY ---"
exit
