set_time_format -unit ns -decimal_places 3

derive_pll_clocks -create_base_clocks  
derive_clock_uncertainty

create_clock -name SYS_RefClk             -period  10.000 -waveform {0.000  5.000} [get_ports {SYS_RefClk}]
create_clock -name ETH_RefClk             -period   3.103 -waveform {0.000  1.600} [get_ports {ETH_RefClk}]
create_clock -name {altera_reserved_tck}  -period 100.000 -waveform {0.000 50.000} [get_ports {altera_reserved_tck}]

set_clock_groups -asynchronous\
 -group [get_clocks {*|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|outclk0}]\
 -group [get_clocks {*|qph_user_clk_fpll_u0|xcvr_fpll_a10_0|outclk1}]\
 -group [get_clocks {SYS_RefClk}]\
 -group [get_clocks {ETH_RefClk}]\
 -group [get_clocks {altera_reserved_tck}]\
 -group [get_clocks {mem|ddr4a|ddr4a_ref_clock}]\
 -group [get_clocks {fpga_top|inst_fiu_top|inst_pcie0_ccib_top|pcie_hip0|pcie_a10_hip_0|wys~CORE_CLK_OUT}]\
 -group [get_clocks u0|dcp_iopll|dcp_iopll|clk2x]\
 -group [get_clocks u0|dcp_iopll|dcp_iopll|clk1x]\
 -group [get_clocks {DDR4A_DQS_P[*]_IN DDR4B_DQS_P[*]_IN mem|ddr4a|ddr4a_core_usr_clk mem|ddr4a|ddr4a_phy_clk_* mem|ddr4b|ddr4b_phy_clk_*}]

set_false_path -from [get_registers {fpga_top|inst_fiu_top|*|PR_IP|*|freeze_reg}] -to *
set_false_path -from [get_ports PCIE_RESET_N] -to *
