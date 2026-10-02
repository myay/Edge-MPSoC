# =============================================================================
# Shared Utility Procedures for Vivado Build Flow
# =============================================================================

proc import_filelist {filelist_path} {
    if {![file exists $filelist_path]} {
        error "Filelist not found: $filelist_path"
    }

    set filelist_dir [file dirname [file normalize $filelist_path]]
    set fp [open $filelist_path r]
    set file_data [read $fp]
    close $fp

    set sources  {}
    set inc_dirs {}
    set defines  {}

    foreach line [split $file_data "\n"] {
        # Strip comments
        set line [regsub {//.*$} $line ""]
        set line [regsub {#.*$}  $line ""]
        
        # Trim whitespace and double quotes
        set line [string trim $line " \t\r\n\""]

        if {$line eq ""} { continue }

        # Expand ${VAR_NAME} environment variables
        while {[regexp {\$\{([A-Za-z0-9_]+)\}} $line -> var_name]} {
            if {[info exists ::env($var_name)]} {
                set env_val $::env($var_name)
                set line [string map [list "\${$var_name}" $env_val] $line]
            } else {
                error "ERROR: Environment variable '\$$var_name' referenced in filelist is not set!"
            }
        }

        # Expand $VAR_NAME environment variables
        while {[regexp {\$([A-Za-z_][A-Za-z0-9_]*)} $line -> var_name]} {
            if {[info exists ::env($var_name)]} {
                set env_val $::env($var_name)
                set line [string map [list "\$$var_name" $env_val] $line]
            } else {
                error "ERROR: Environment variable '\$$var_name' referenced in filelist is not set!"
            }
        }

        if {[string match "+incdir+*" $line]} {
            set raw_inc [string range $line 8 end]
            lappend inc_dirs [file normalize [file join $filelist_dir $raw_inc]]
        } elseif {[string match "+define+*" $line]} {
            lappend defines [string range $line 8 end]
        } else {
            lappend sources [file normalize [file join $filelist_dir $line]]
        }
    }

    if {[llength $sources] > 0} {
        read_verilog -sv $sources
    }
    if {[llength $inc_dirs] > 0} {
        set_property include_dirs $inc_dirs [get_filesets sources_1]
    }
    if {[llength $defines] > 0} {
        set_property verilog_define $defines [get_filesets sources_1]
    }

    puts "Imported [llength $sources] sources, [llength $inc_dirs] incdirs, [llength $defines] defines from $filelist_path"
}
