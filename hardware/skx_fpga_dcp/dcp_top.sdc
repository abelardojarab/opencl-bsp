set_time_format -unit ns -decimal_places 3

derive_pll_clocks -create_base_clocks  
derive_clock_uncertainty

create_clock -name SYS_RefClk             -period  10.000 -waveform {0.000  5.000} [get_ports {SYS_RefClk}]
create_clock -name ETH_RefClk             -period   3.103 -waveform {0.000  1.600} [get_ports {ETH_RefClk}]
create_clock -name {altera_reserved_tck}  -period 100.000 -waveform {0.000 50.000} [get_ports {altera_reserved_tck}]

set_clock_groups -logically_exclusive -group [get_clocks {*|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|outclk0}] -group [get_clocks {*|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|outclk1}] -group [get_clocks {SYS_RefClk}] -group [get_clocks {ETH_RefClk}] -group [get_clocks {fpga_top|inst_fiu_top|inst_pcie0_ccib_top|pcie_hip0|pcie_a10_hip_0|wys~CORE_CLK_OUT}] -group [get_clocks u0\|dcp_iopll\|clk2x] -group [get_clocks u0\|dcp_iopll\|clk1x] 


#new: fpga_top|inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_inst|refclk
#old: inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_refclk_select_inst|refclk

#new: fpga_top|inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_inst|outclk[0]
#old: inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_inst|outclk[0]

##create_generated_clock -name {uClk_usrDiv2} -source [get_pins {fpga_top|inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_inst|refclk}] -duty_cycle 50/1 -multiply_by 25 -divide_by 16 -master_clock {SYS_RefClk} [get_pins {fpga_top|inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_inst|outclk[0]}] 
##set_clock_uncertainty -rise_from [get_clocks {uClk_usrDiv2}] -rise_to [get_clocks {uClk_usrDiv2}]  0.030  
##set_clock_uncertainty -rise_from [get_clocks {uClk_usrDiv2}] -fall_to [get_clocks {uClk_usrDiv2}]  0.030  
##set_clock_uncertainty -fall_from [get_clocks {uClk_usrDiv2}] -rise_to [get_clocks {uClk_usrDiv2}]  0.030  
##set_clock_uncertainty -fall_from [get_clocks {uClk_usrDiv2}] -fall_to [get_clocks {uClk_usrDiv2}]  0.030  
##
##create_generated_clock -name {uClk_usr} -source [get_pins {fpga_top|inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_inst|refclk}] -duty_cycle 50/1 -multiply_by 25 -divide_by 8 -master_clock {SYS_RefClk} [get_pins {fpga_top|inst_fiu_top|inst_ccip_fabric_top|inst_cvl_top|inst_user_clk|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|fpll_inst|outclk[1]}] 
##set_clock_uncertainty -rise_from [get_clocks {uClk_usr}] -rise_to [get_clocks {uClk_usr}]  0.030  
##set_clock_uncertainty -rise_from [get_clocks {uClk_usr}] -fall_to [get_clocks {uClk_usr}]  0.030  
##set_clock_uncertainty -fall_from [get_clocks {uClk_usr}] -rise_to [get_clocks {uClk_usr}]  0.030  
##set_clock_uncertainty -fall_from [get_clocks {uClk_usr}] -fall_to [get_clocks {uClk_usr}]  0.030  
