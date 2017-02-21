# (C) 1992-2016 Altera Corporation. All rights reserved.                         
# Your use of Altera Corporation's design tools, logic functions and other       
# software and tools, and its AMPP partner logic functions, and any output       
# files any of the foregoing (including device programming or simulation         
# files), and any associated documentation or information are expressly subject  
# to the terms and conditions of the Altera Program License Subscription         
# Agreement, Altera MegaCore Function License Agreement, or other applicable     
# license agreement, including, without limitation, that your use is for the     
# sole purpose of programming logic devices manufactured by Altera and sold by   
# Altera or its authorized distributors.  Please refer to the applicable         
# agreement for further details.                                                 
    
# helper function to recursively get file list in given directory
proc getfiles { dir } {
  set f ""
 
  # get current directory contents
  set contents [glob -nocomplain -directory $dir *]

  # empty directory -> need to create file in it, so that qar picks up the directory
  if { [llength $contents] == 0 } {
    set tempfile [open "$dir/dummy.txt" w]
    close $tempfile
    lappend contents "$dir/dummy.txt"
  }

  # step through all directory contents
  foreach item $contents {
    if { [file isdirectory $item] } {
      # recursively call this function for subdirectories
      append f [getfiles $item] 
    } elseif { [file isfile $item]} {
      # add only found files to list that are from "final" Quartus compile stage  
      if { [info exists include_item] } { unset include_item }
      regexp {final.*$} $item include_item
      if { [info exists include_item] } {
        # do not add timing database files with "nightfury_io_sim_cache", "timing", "pticmp"
        if { [info exists exclude_item] } { unset exclude_item }
        regexp {(nightfury|timing|pticmp).*$} $item exclude_item
        if { ![info exists exclude_item] } {
          append f "$item\n"
        }
      } 
    }
  }
  return $f
}

##############################################################################
##############################       MAIN        #############################
##############################################################################

post_message "Running post-flow script"

set project_name UNKNOWN
set revision_name UNKNOWN

if { [llength $quartus(args) ] == 0 } {
  # If this script is run manually, just compile the default revision
  set qpf_files [glob -nocomplain *.qpf]

  if {[llength $qpf_files] == 0} {
    error "No QSF detected"
  } elseif {[llength $qpf_files] > 1} {
    post_message "Warning: More than one QSF detected. Picking the first one."
  }
  set qpf_file [lindex $qpf_files 0]
  set project_name [string range $qpf_file 0 [expr [string first . $qpf_file] - 1]]
  set revision_name [get_current_revision $project_name]
} else {
  set project_name [lindex $quartus(args) 1]
  set revision_name [lindex $quartus(args) 2]
}

post_message "Project name: $project_name"
post_message "Revision name: $revision_name"

# Make sure OpenCL SDK installation exists
post_message "Checking for OpenCL SDK installation, environment should have ALTERAOCLSDKROOT defined"
if {[catch {set sdk_root $::env(ALTERAOCLSDKROOT)} result]} {
  post_message -type error "OpenCL SDK installation not found.  Make sure ALTERAOCLSDKROOT is correctly set"
  post_message -type error "Terminating post-flow script"
  exit 2
} else {
  post_message "ALTERAOCLSDKROOT=$::env(ALTERAOCLSDKROOT)"
}

if {[string match $revision_name "base"]} {
 
  load_package flow
  load_package design
  project_open top -revision base
  
  post_message "Compiling base revision -> exporting the static block of the base revision to QDB archive root_partition.qdb!"
  if {[catch {design::export_block root_partition -snapshot final -file root_partition.qdb -exclude_pr_subblocks} result]} {
    post_message -type error "Error! Failed to export base root_partition $result"
    exit 2
  } 

  post_message "Compiling base revision -> exporting the base revision compile database to QDB archive base.qdb!"
  if {[catch {design::export_design -snapshot final -file base.qdb} result]} {
    post_message -type error "Error! Failed to export base design $result"
    exit 2
  } 
  project_close
 
  # Generate a file that contains information about the version of quartus used to generate this base compile
  qexec "quartus_sh --version > base_qdb_version.txt"
}

# run PR checks script
source $::env(ALTERAOCLSDKROOT)/ip/board/bsp/pr_checks_a10.tcl

# run adjust PLL script
source $::env(ALTERAOCLSDKROOT)/ip/board/bsp/adjust_plls_a10.tcl

# create partial reconfiguration files (for top revision)
post_message "Creating partial reconfiguration files"
if {[string match $revision_name "base"]} {
  post_message "Compiling base revision -> PR file generation not available for this revision!"
} elseif {[string match $revision_name "top"]} {
  post_message "Compiling top revision -> generating PR files"

  post_message "Running quartus_cpf for .pmsf"
  set msffile [glob -nocomplain top.*.msf]
  qexec "quartus_cpf -p $msffile top.sof top.pmsf"

  post_message "Running quartus_cpf for .rbf"
  qexec "quartus_cpf -c top.pmsf top.rbf"
} elseif {[string match $revision_name "flat"]} {
  post_message "Compiling flat revision -> PR file generation not available for this revision!"
}

# create fpga.bin
post_message "Running create_fpga_bin_pr.tcl script"
if {[string match $revision_name "base"]} {
  post_message "Compiling base revision -> adding only base.sof to fpga.bin!"
  qexec "quartus_cdb -t scripts/create_fpga_bin_pr.tcl base.sof"
} elseif {[string match $revision_name "top"]} {
  post_message "Compiling top revision -> adding top.sof, top.rbf and pr_base_id.txt to fpga.bin!"
  qexec "quartus_cdb -t scripts/create_fpga_bin_pr.tcl top.sof top.rbf pr_base_id.txt"
} elseif {[string match $revision_name "flat"]} {
  post_message "Compiling flat revision -> adding only flat.sof to fpga.bin!"
  qexec "quartus_cdb -t scripts/create_fpga_bin_pr.tcl flat.sof"
} 

