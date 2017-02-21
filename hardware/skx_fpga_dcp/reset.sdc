set_multicycle_path -to * -setup 2 -from {inst_green_bs|inst_ccip_std_afu|u0|board_inst|cci_interface|rst_controller|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain_out}
set_multicycle_path -to * -hold 1 -from {inst_green_bs|inst_ccip_std_afu|u0|board_inst|cci_interface|rst_controller|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain_out}


# Make the kernel reset multicycle
set_multicycle_path -to * -setup 4 -from {inst_green_bs|inst_ccip_std_afu|u0|board_inst|kernel_interface|reset_controller_sw|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain_out}
set_multicycle_path -to * -hold 3 -from {inst_green_bs|inst_ccip_std_afu|u0|board_inst|kernel_interface|reset_controller_sw|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain_out}
set_multicycle_path -to * -setup 4 -from {inst_green_bs|inst_ccip_std_afu|u0|freeze_wrapper_inst|kernel_system_clock_reset_reset_reset_n}
set_multicycle_path -to * -hold 3 -from {inst_green_bs|inst_ccip_std_afu|u0|freeze_wrapper_inst|kernel_system_clock_reset_reset_reset_n}

# Multicycle-path for afu reset
set_multicycle_path -to * -setup 2 -from {inst_blue_ccip_interface_reg|pck_cp2af_softReset_T0_q}
set_multicycle_path -to * -hold 1 -from {inst_blue_ccip_interface_reg|pck_cp2af_softReset_T0_q}

# Cut path to twoXclock_consumer (this instance is only there to keep 
# kernel interface consistent and prevents kernel_clk2x to be swept away by synthesis)
set_false_path -from * -to inst_green_bs|inst_ccip_std_afu|u0|freeze_wrapper_inst|kernel_wrapper_inst|kernel_system_inst|*|*|kernel|twoXclock_consumer_NO_SHIFT_REG

# Cut path to freeze signal - this signal is asynchronous
set_false_path -from bot_wcp|inst_ccip_fabric_top|inst_fme_top|inst_PR_cntrl|PR_IP|alt_pr_0|alt_pr_cb_host|alt_pr_cb_controller_v2|freeze_reg -to *
# Relax Kernel constraints - only do this during base revision compiles
if {! [string equal $::TimeQuestInfo(nameofexecutable) "quartus_map"]} {
  # case:196028 can't call get_current_revision in parallel map
  if { [get_current_revision] eq "base" } {
    post_message -type critical_warning "Compiling with slowed OpenCL Kernel clock.  This is to help achieve timing closure for board bringup."
    if {! [string equal $::TimeQuestInfo(nameofexecutable) "quartus_sta"]} {
      set kernel_keepers [get_keepers inst_ccip_interface_reg\|inst_green_top\|inst_ccip_std_afu\|u0\|freeze_wrapper_inst\|kernel_wrapper_inst\|*] 
      set_max_delay 5 -from $kernel_keepers -to $kernel_keepers
    }
  }
}




# Relax Kernel constraints - only do this during base revision compiles
if {! [string equal $::TimeQuestInfo(nameofexecutable) "quartus_map"]} {
# Case 196028 can't call get_current_revision in parallel map

if { [get_current_revision] eq "base" } {

  post_message -type critical_warning "Compiling with slowed OpenCL Kernel clock.  This is to help achieve timing closure for board bringup."

  if {! [string equal $::TimeQuestInfo(nameofexecutable) "quartus_sta"]} {
    set kernel_keepers [get_keepers inst_green_bs|inst_ccip_std_afu|u0|freeze_wrapper_inst|kernel_wrapper_inst|*] 
    set_max_delay 5 -from $kernel_keepers -to $kernel_keepers
  }
}

}