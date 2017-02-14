
load_package flow
load_package design

# Generate board.qsys and kernel_system.qsys Qsys files
qexec "quartus_sh -t scripts/pre_flow_pr.tcl compile top top"
 
# Synthesize PR logic
qexec "quartus_syn top -c top_synth"

# Exporting the kernel from the top_synth compile
project_open top -revision top_synth
if {[catch {design::export_block root_partition -snapshot synthesized -file kernel.qdb} result]} {
  post_message -type error "Error! $result"
  exit 2
}
project_close

# Importing static partition from base revision compile
project_open top -revision top
if {[catch {design::import_block root_partition -file root_partition.qdb} result]} {
  post_message -type error "Error! $result"
  exit 2
}
project_close

# Importing the kernel from the top_synth compile
project_open top -revision top
if {[catch {design::import_block kernel -file kernel.qdb} result]} {
  post_message -type error "Error! $result"
  exit 2
}
project_close

# Replace base compile's PR logic with different PR logic
qexec "quartus_fit top -c top"
qexec "quartus_sta top -c top"

# Generate report, generate PLL configuration file, re-run STA
qexec "quartus_cdb -t scripts/post_flow_pr.tcl"

