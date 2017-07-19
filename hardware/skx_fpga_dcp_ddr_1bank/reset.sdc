# Make the kernel reset multicycle
set_multicycle_path -to * -setup 4 -from {*inst_green_bs|inst_ccip_std_afu|bsp_logic_inst|u0|board_inst|kernel_interface|reset_controller_sw|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain_out}                                        
set_multicycle_path -to * -hold 3 -from {*inst_green_bs|inst_ccip_std_afu|bsp_logic_inst|u0|board_inst|kernel_interface|reset_controller_sw|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain_out}
set_multicycle_path -to * -setup 4 -from {*inst_green_bs|inst_ccip_std_afu|freeze_wrapper_inst|kernel_system_clock_reset_reset_reset_n}
set_multicycle_path -to * -hold 3 -from {*inst_green_bs|inst_ccip_std_afu|freeze_wrapper_inst|kernel_system_clock_reset_reset_reset_n}

# Multicycle-path for afu reset
set_multicycle_path -to * -setup 2 -from {*inst_blue_ccip_interface_reg|pck_cp2af_softReset_T0_q}
set_multicycle_path -to * -hold 1 -from {*inst_blue_ccip_interface_reg|pck_cp2af_softReset_T0_q}

# Cut path to twoXclock_consumer (this instance is only there to keep 
# kernel interface consistent and prevents kernel_clk2x to be swept away by synthesis)
set_false_path -from * -to {*inst_green_bs|inst_ccip_std_afu|freeze_wrapper_inst|kernel_wrapper_inst|kernel_system_inst|*|*|kernel|twoXclock_consumer_NO_SHIFT_REG}

set_false_path -from * -to {*inst_green_bs|uClk_usr_q1}
set_false_path -from * -to {*inst_green_bs|uClk_usr_q2}
#                           inst_green_bs|inst_ccip_std_afu|freeze_wrapper_inst|kernel_wrapper_inst|kernel_system_inst|mem_bandwidth_system|memwrite|kernel|twoXclock_consumer_NO_SHIFT_REG
# Cut path to freeze signal - this signal is asynchronous
set_false_path -from *|inst_ccip_fabric_top|inst_fme_top|inst_PR_cntrl|PR_IP|alt_pr_0|alt_pr_cb_host|alt_pr_cb_controller_v2|freeze_reg -to *


# need to wildcard localized resets for recovery timing
set_multicycle_path -to * -setup 4 -from {*|sync_rstn_MS[*]}   
set_multicycle_path -to * -hold 3 -from  {*|sync_rstn_MS[*]}   

#inst_green_bs|inst_ccip_std_afu|freeze_wrapper_inst|kernel_wrapper_inst|kernel_system_inst|mem_bandwidth_system|memcopy|kernel|memcopy_function_inst0|memcopy_basic_block_1|lsu_local_bb1_st_|sync_rstn_MS[1]

if {! [string equal $::TimeQuestInfo(nameofexecutable) "quartus_sta"]} {
  # tighten Kernel constraints during flat compile
  # create_clock -name {uClk_usrDiv2} -period 4 [get_pins {inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_inst|outclk[0]}] 
  # create_clock -name {uClk_usr} -period 2 [get_pins {inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_inst|outclk[1]}] 

  # also tighten 400 MHZ clock for better timing closure
  # create_clock -name {pClk} -period 2 [get_pins {inst_fiu_top|kti_top|kti_phy|inst_kti_phy|altera_upiphy_intccru_inst|core_pll|xcvr_fpll_a10_0|fpll_inst|outclk[0]}] 

}
  


