#Run using: quartus_sta -t <script.tcl> <project>
set report_file acl_clocks_iface.txt
set kclk_name "kernel_clk"
set kclk_name_alt "*kernel_pll*0]*divclk"

set report_timing_args "*kernel_pll*0]*divclk"

if { $argc != 1} {error "Error: Usage: quartus_sta -t <script.tcl> <project_name>" }

set proj [lindex $argv 0]

proc get_min { vals } {
  set min [lindex $vals 0]
  foreach v $vals {
    if { $min > $v } {
      set min $v
    }
  }
  return $min
}

project_open $proj
#create_timing_netlist -model slow 
create_timing_netlist 
read_sdc

set slacks [list]

file delete -force $report_file

set kclk $kclk_name
if { [ get_collection_size [get_clocks $kclk_name] ] != 1 } {
  post_message "Couldn't find clock $kclk_name, using $$kclk_name_alt"
  set kclk $kclk_name_alt
}

post_message "Using kernel clk: $kclk\n"

foreach_in_collection op_condition [get_available_operating_conditions] {

  set_operating_conditions $op_condition
  update_timing_netlist

  foreach analysis [list setup recovery] {
    lappend slacks [lindex [report_timing -$analysis  -to_clock [get_clocks $kclk] -to [get_keepers system_inst|acl_iface*] -from [get_keepers system_inst|acl_iface*] -npaths 5 -detail full_path -panel_name {Kernel 1x Clock Setup} -file $report_file -append] 1]
  }
}

set k_period [get_clock_info  -period $kclk]

post_message "Slacks for kernel_clk: [join $slacks]"

set minslack [ get_min $slacks ]

set k_actual_period [ expr $k_period - $minslack]
set k_fmax [ expr 1000.0 / $k_actual_period ]

post_message "Minimum slack for kernel_clk: $minslack"
post_message "Clock Period constraint for kernel_clk: $k_period"
post_message "Clock Period actual for kernel_clk: $k_actual_period"


project_close

post_message "===== Kernel clk iface fmax: $k_fmax MHz ====="

set f [open maxfmax.txt w]
puts $f $k_fmax
close $f

