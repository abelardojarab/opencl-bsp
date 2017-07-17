# (C) 2017 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other
# software and tools, and its AMPP partner logic functions, and any output
# files any of the foregoing (including device programming or simulation
# files), and any associated documentation or information are expressly subject
# to the terms and conditions of the Intel Program License Subscription
# Agreement, Intel MegaCore Function License Agreement, or other applicable
# license agreement, including, without limitation, that your use is for the
# sole purpose of programming logic devices manufactured by Intel and sold by
# Intel or its authorized distributors.  Please refer to the applicable
# agreement for further details.

# Required packages
package require ::quartus::project
package require ::quartus::report
package require ::quartus::flow

#clocks paths from afu
#these names are extracted from afu_fit.sta.rpt

set pClk_name "u0|dcp_iopll|dcp_iopll|clk2x"
set pClkDiv2_name "u0|dcp_iopll|dcp_iopll|clk1x"
set pClkDiv4_name "SYS_RefClk"
set uClk_usr_name "fpga_top|inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|outclk1"
set uClk_usrDiv2_name "fpga_top|inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|outclk0"
set DDR4a_USERCLK_name "mem|ddr4a|ddr4a_core_usr_clk"
set DDR4b_USERCLK_name "mem|ddr4b|ddr4b_core_usr_clk"

set jitter_compensation 0.01

# Return values: [retval panel_id row_index]
#   panel_id and row_index are only valid if the query is successful
# retval: 
#    0: success
#   -1: not found
#   -2: panel not found (could be report not loaded)
#   -3: no rows found in panel
#   -4: multiple matches found
proc find_report_panel_row { panel_name col_index string_op string_pattern } {
    if {[catch {get_report_panel_id $panel_name} panel_id] || $panel_id == -1} {
        return -2;
    }

    if {[catch {get_number_of_rows -id $panel_id} num_rows] || $num_rows == -1} {
        return -3;
    }

    # Search for row match.
    set found 0
    set row_index -1;
	
    for {set r 1} {$r < $num_rows} {incr r} {
        if {[catch {get_report_panel_data -id $panel_id -row $r -col $col_index} value] == 0} {


            if {[string $string_op $string_pattern $value]} {
                if {$found == 0} {

                    # If multiple rows match, return the first
                    set row_index $r

                }
                incr found
            }

        }
    }

    if {$found > 1} {return [list -4 $panel_id $row_index]}
    if {$row_index == -1} {return -1}

    return [list 0 $panel_id $row_index]
}


# get_fmax_from_report: Determines the fmax for the given clock. The fmax value returned
# will meet all timing requirements (setup, hold, recovery, removal, minimum pulse width)
# across all corners.  The return value is a 2-element list consisting of the
# fmax and clk name
proc get_fmax_from_report { clkname required jitter_compensation} {
    # Find the clock period.
    set result [find_report_panel_row "TimeQuest Timing Analyzer||Clocks" 0 match $clkname]
    set retval [lindex $result 0]
   
    if {$retval == -1} { 
        if {$required == 1} {
           error "Error: Could not find clock: $clkname" 
        } else {
           post_message -type warning "Could not find clock: $clkname.  Clock is not required assuming 10 GHz and proceeding."
           return [list 10000 $clkname]
        }
    } elseif {$retval < 0} { 
        error "Error: Failed search for clock $clkname (error $retval)"
    }

    # Update clock name to full clock name ($clkname as passed in may contain wildcards).
    set panel_id [lindex $result 1]
    set row_index [lindex $result 2]
    set clkname [get_report_panel_data -id $panel_id -row $row_index -col 0]
    set clk_period [get_report_panel_data -id $panel_id -row $row_index -col 2]

    post_message "Clock $clkname"
    post_message "  Period: $clk_period"

    # Determine the most negative slack across all relevant timing metrics (setup, recovery, minimum pulse width)
    # and across all timing corners. Hold and removal metrics are not taken into account
    # because their slack values are independent on the clock period (for kernel clocks at least).
    #
    # Paths that involve both a posedge and negedge of the kernel clocks are not handled properly (slack
    # adjustment needs to be doubled).
    set timing_metrics [list "Setup" "Recovery" "Minimum Pulse Width"]
    set timing_metric_colindex [list 1 3 5 ]
    set timing_metric_required [list 1 0 0]
    set wc_slack $clk_period
    set has_slack 0
    set fmax_from_summary 5000.0

    # Find the "Fmax Summary" numbers reported in Quartus.  This may not
    # account for clock transfers but it does account for pos-to-neg edge same
    # clock transfers.  Whatever we calculate should be less than this.
    set fmax_panel_name "TimeQuest Timing Analyzer||* Model||* Model Fmax Summary"
    foreach panel_name [get_report_panel_names] {
      if {[string match $fmax_panel_name $panel_name] == 1} {
        set result [find_report_panel_row $panel_name 2 equal $clkname]
        set retval [lindex $result 0]
        if {$retval == 0} {
          set restricted_fmax_field [get_report_panel_data -id [lindex $result 1] -row [lindex $result 2] -col 1]
          regexp {([0-9\.]+)} $restricted_fmax_field restricted_fmax 
          if {$restricted_fmax < $fmax_from_summary} {
            set fmax_from_summary $restricted_fmax
          }
        }
      }
    }
    post_message "  Restricted Fmax from STA: $fmax_from_summary"

    # Find the worst case slack across all corners and metrics
    foreach metric $timing_metrics metric_required $timing_metric_required col_ndx $timing_metric_colindex {
      set panel_name "TimeQuest Timing Analyzer||Multicorner Timing Analysis Summary"
      set panel_id [get_report_panel_id $panel_name] 
      set result [find_report_panel_row $panel_name 0 equal " $clkname"]
      set retval [lindex $result 0]

      if {$retval == -1} { 
        if {$required == 1 && $metric_required == 1} {
          error "Error: Could not find clock: $clkname" 
        }
      } elseif {$retval < 0 && $retval != -4 } { 
        error "Error: Failed search for clock $clkname (error $retval)"
      }

      if {$retval == 0 || $retval == -4} {
        set slack [get_report_panel_data -id [lindex $result 1] -row [lindex $result 2] -col $col_ndx ]
        post_message "    $metric slack: $slack"
        if {$slack != "N/A"} {
          if {$metric == "Setup" || $metric == "Recovery"} {
            set has_slack 1
            if {$metric == "Recovery"} {
              set normalized_slack [ expr $slack / 4.0 ]
              post_message "    normalized $metric slack: $normalized_slack"
              set slack $normalized_slack
            }
          }
        } 
        # Keep track of the most negative slack.
        if {$slack < $wc_slack} {
          set wc_slack $slack
          set wc_metric $metric
        }
      }
    }

    if {$has_slack == 1} {
        # Adjust the clock period to meet the worst-case slack requirement.
        set clk_period [expr $clk_period - $wc_slack + $jitter_compensation]
        post_message "  Adjusted period: $clk_period ([format %+0.3f [expr -$wc_slack]], $wc_metric)"

        # Compute fmax from clock period. Clock period is in nanoseconds and the
        # fmax number should be in MHz.
        set fmax [expr 1000 / $clk_period]

        if {$fmax_from_summary < $fmax} {
            post_message "  Restricted Fmax from STA is lower than $fmax, using it instead."
            set fmax $fmax_from_summary
        }

        # Truncate to two decimal places. Truncate (not round to nearest) to avoid the
        # very small chance of going over the clock period when doing the computation.
        set fmax [expr floor($fmax * 100) / 100]
        post_message "  Fmax: $fmax"
    } else {
        post_message -type warning "No slack found for clock $clkname - assuming 10 GHz."
        set fmax 10000
    }

    return [list $fmax $clkname]
}

##############################################################################
##############################       MAIN        #############################
##############################################################################

post_message "Running adjust PLLs script"

set project_name "dcp"
set revision_name "afu_fit"



if { [llength $quartus(args) ] != 2 } {
    error "Usage: quartus_sh -t script.tcl project_name revision_name"
} else {
  set project_name [lindex $quartus(args) 0]
  set revision_name [lindex $quartus(args) 1]
}


post_message "Project name: $project_name"
post_message "Revision name: $revision_name"

load_package design
project_open $project_name -revision $revision_name
design::load_design -writeable -snapshot final
load_report $revision_name

set panel_names [get_report_panel_names]

# get device speedgrade
set part_name [get_global_assignment -name DEVICE]
post_message "Device part name is $part_name"
set report [report_part_info $part_name]
regexp {Speed Grade.*$} $report speedgradeline
regexp {(\d+)} $speedgradeline speedgrade
if { $speedgrade < 1 || $speedgrade > 8 } {
  post_message "Speedgrade is $speedgrade and not in the range of 1 to 8"
  post_message "Terminating post-flow script"
  return TCL_ERROR
}
post_message "Speedgrade is $speedgrade"

#extract fmax numbers
set pClk_fmax [ lindex [ get_fmax_from_report $pClk_name 1 $jitter_compensation] 0 ]
set pClkDiv2_fmax [ lindex [ get_fmax_from_report $pClkDiv2_name 1 $jitter_compensation] 0 ]
set pClkDiv4_fmax [ lindex [ get_fmax_from_report $pClkDiv4_name 1 $jitter_compensation] 0 ]
set uClk_usr_fmax [ lindex [ get_fmax_from_report $uClk_usr_name 1 $jitter_compensation] 0 ]
set uClk_usrDiv2_fmax [ lindex [ get_fmax_from_report $uClk_usrDiv2_name 1 $jitter_compensation] 0 ]
set DDR4a_USERCLK_fmax [ lindex [ get_fmax_from_report $DDR4a_USERCLK_name 1 $jitter_compensation] 0 ]
set DDR4b_USERCLK_fmax [ lindex [ get_fmax_from_report $DDR4b_USERCLK_name 1 $jitter_compensation] 0 ]

design::unload_design

project_open $project_name -revision $revision_name
load_report $revision_name

post_message "Generating afu_quartus_report.txt"
set outfile   [open "afu_quartus_report.txt" w]
set aluts_l   [regsub "," [get_fitter_resource_usage -alut] "" ]
if {[catch {set aluts_m [regsub "," [get_fitter_resource_usage -resource "Memory ALUT usage"] "" ]} result]} {
  set aluts_m 0
}
if { [string length $aluts_m] < 1 || ! [string is integer $aluts_m] } {
  set aluts_m 0
}
set aluts     [expr $aluts_l + $aluts_m]
set registers [get_fitter_resource_usage -reg]
set logicutil [get_fitter_resource_usage -utilization]
set io_pin    [get_fitter_resource_usage -io_pin]
set dsp       [get_fitter_resource_usage -resource "*DSP*"]
set mem_bit   [get_fitter_resource_usage -mem_bit]
set m9k       [get_fitter_resource_usage -resource "M?0K*"]
puts $outfile "ALUTs: $aluts"
puts $outfile "Registers: $registers"
puts $outfile "Logic utilization: $logicutil"
puts $outfile "I/O pins: $io_pin"
puts $outfile "DSP blocks: $dsp"
puts $outfile "Memory bits: $mem_bit"
puts $outfile "RAM blocks: $m9k"

# Highest non-global fanout signal
set result [find_report_panel_row "Fitter||Place Stage||Fitter Resource Usage Summary" 0 equal "Highest non-global fan-out"]
if {[lindex $result 0] < 0} {error "Error: Could not find highest non-global fan-out (error $retval)"}
set high_fanout_signal_fanout_count [get_report_panel_data -id [lindex $result 1] -row [lindex $result 2] -col 1]

# fmax numbers
puts $outfile "Highest non-global fanout: $high_fanout_signal_fanout_count"
puts $outfile "pClk fmax: $pClk_fmax"
puts $outfile "pClkDiv2 fmax: $pClkDiv2_fmax"
puts $outfile "pClkDiv4 fmax: $pClkDiv4_fmax"
puts $outfile "uClk_usr fmax: $uClk_usr_fmax"
puts $outfile "uClk_usrDiv2 fmax: $uClk_usrDiv2_fmax"
puts $outfile "DDR4a_USERCLK fmax: $DDR4a_USERCLK_fmax"
puts $outfile "DDR4b_USERCLK fmax: $DDR4b_USERCLK_fmax"

close $outfile
# End little report

design::unload_design
project_close

