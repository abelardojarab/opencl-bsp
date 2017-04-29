# +-----------------------------------
# | 
# | altera_avalon_mm_cci_bridge "Avalon-MM to CCI Bridge"
# | 
# +-----------------------------------

# +-----------------------------------
# | request TCL package from ACDS 13.1
# | 
package require -exact qsys 13.1
# | 
# +-----------------------------------

# +-----------------------------------
# | module altera_avalon_mm_cci_bridge
# | 
set_module_property DESCRIPTION "This component creates a bridge between an Avalon-MM master and a CCI Standard interface."
set_module_property NAME altera_avalon_mm_cci_bridge
set_module_property VERSION 13.1
set_module_property GROUP "Basic Functions/Bridges and Adaptors/Memory Mapped"
set_module_property AUTHOR "Altera Corporation"
set_module_property DISPLAY_NAME "Avalon-MM to CCI Bridge"
set_module_property AUTHOR "Altera Corporation"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property ELABORATION_CALLBACK elaborate
set_module_property DATASHEET_URL http://www.altera.com/#update_me_with_actual_link
# | 
# +-----------------------------------

# +-----------------------------------
# | files
# | 
add_fileset bridge_synth QUARTUS_SYNTH add_files
add_fileset bridge_sim   SIM_VERILOG   add_files
set_fileset_property 	 bridge_synth TOP_LEVEL altera_avalon_mm_cci_bridge
set_fileset_property 	 bridge_sim   TOP_LEVEL altera_avalon_mm_cci_bridge

proc add_files { toplevel } {
	add_fileset_file altera_avalon_mm_cci_bridge.v VERILOG PATH ./altera_avalon_mm_cci_bridge.v TOP_LEVEL_FILE
	add_fileset_file cci_read_granter.v VERILOG PATH ./cci_read_granter.v
	add_fileset_file cci_write_granter.v VERILOG PATH ./cci_write_granter.v
	add_fileset_file cci_requester.v VERILOG PATH ./cci_requester.v
  add_fileset_file addr_range_cmp.v VERILOG PATH ./addr_range_cmp.v
}
# | 
# +-----------------------------------

# +-----------------------------------
# | parameters
# | 

# | 
# +-----------------------------------

# +-----------------------------------
# | connection point clk
# | 
add_interface clk clock end
add_interface reset_n reset end

set_interface_property clk ENABLED true
set_interface_property reset_n ENABLED true
set_interface_property reset_n ASSOCIATED_CLOCK clk

add_interface_port clk clk clk Input 1
add_interface_port reset_n reset_n reset_n Input 1
# | 
# +-----------------------------------

# +-----------------------------------
# | connection point CCI Conduit
# | 
add_interface cci0 conduit start

add_interface_port cci0 InitDone         InitDone input 1
add_interface_port cci0 virtual_access    virtual_access input 1

add_interface_port cci0 tx_c0_almostfull tx_c0_almostfull input 1
add_interface_port cci0 rx_c0_header     rx_c0_header input 28
add_interface_port cci0 rx_c0_data       rx_c0_data input 512
add_interface_port cci0 rx_c0_wrvalid    rx_c0_wrvalid input 1
add_interface_port cci0 rx_c0_rdvalid    rx_c0_rdvalid input 1  

add_interface_port cci0 rx_c0_ugvalid    rx_c0_ugvalid  input 1
add_interface_port cci0 rx_c0_mmiordvalid   rx_c0_mmiordvalid input 1
add_interface_port cci0 rx_c0_mmiowrvalid   rx_c0_mmiowrvalid input 1

add_interface_port cci0 tx_c1_almostfull tx_c1_almostfull input 1
add_interface_port cci0 rx_c1_header     rx_c1_header input 28
add_interface_port cci0 rx_c1_wrvalid    rx_c1_wrvalid input 1
add_interface_port cci0 rx_c1_irvalid rx_c1_irvalid input 1



add_interface_port cci0 tx_c0_header     tx_c0_header output 99
add_interface_port cci0 tx_c0_rdvalid    tx_c0_rdvalid output 1

add_interface_port cci0 tx_c1_header     tx_c1_header output 99
add_interface_port cci0 tx_c1_data       tx_c1_data output 512
add_interface_port cci0 tx_c1_wrvalid    tx_c1_wrvalid output 1
add_interface_port cci0 tx_c1_irvalid    tx_c1_irvalid output 1
add_interface_port cci0 tx_c1_byteen    tx_c1_byteen output 64
add_interface_port cci0 tx_c2_header     tx_c2_header output 9
add_interface_port cci0 tx_c2_rdvalid    tx_c2_rdvalid output 1
add_interface_port cci0 tx_c2_data       tx_c2_data output 64


add_interface_port cci0 nohazards_rd    nohazards_rd output 1
add_interface_port cci0 nohazards_wr_full    nohazards_wr_full output 1
add_interface_port cci0 nohazards_wr_all    nohazards_wr_all output 1

# | 
# +-----------------------------------

# +-----------------------------------
# | connection point Avalon-MM Slave for CCI
# | 
add_interface avmm avalon end
set_interface_property avmm associatedClock clk

set_interface_property avmm ASSOCIATED_CLOCK clk
set_interface_property avmm associatedReset reset_n
set_interface_property avmm ENABLED true
set_interface_property avmm maximumPendingReadTransactions 512
set_interface_property avmm addressUnits WORDS
set_interface_property avmm burstOnBurstBoundariesOnly true

add_interface_port avmm avmm_waitrequest waitrequest output 1
add_interface_port avmm avmm_readdata readdata output 512
add_interface_port avmm avmm_readdatavalid readdatavalid output 1
add_interface_port avmm avmm_burstcount burstcount input 3
add_interface_port avmm avmm_writedata writedata input 512
add_interface_port avmm avmm_address address input 58
add_interface_port avmm avmm_byteenable byteenable input 64
add_interface_port avmm avmm_write write input 1
add_interface_port avmm avmm_read read input 1

# Future use signals
# add_interface_port avmm avmm_byteenable byteenable input 64
# add_interface_port avmm avmm_burstcount burstcount input 2
# | 
# +-----------------------------------

# +-----------------------------------
# | connection point Avalon-MM Slave for CCI Config
# | 
# 
# connection point kernel
# 
add_interface kernel avalon start
set_interface_property kernel addressUnits WORDS
set_interface_property kernel associatedClock clk
set_interface_property kernel associatedReset reset_n
set_interface_property kernel bitsPerSymbol 8
set_interface_property kernel burstOnBurstBoundariesOnly false
set_interface_property kernel burstcountUnits WORDS
set_interface_property kernel doStreamReads false
set_interface_property kernel doStreamWrites false
set_interface_property kernel holdTime 0
set_interface_property kernel linewrapBursts false
set_interface_property kernel maximumPendingReadTransactions 0
set_interface_property kernel maximumPendingWriteTransactions 0
set_interface_property kernel readLatency 0
set_interface_property kernel readWaitTime 1
set_interface_property kernel setupTime 0
set_interface_property kernel timingUnits Cycles
set_interface_property kernel writeWaitTime 0
set_interface_property kernel ENABLED true
set_interface_property kernel EXPORT_OF ""
set_interface_property kernel PORT_NAME_MAP ""
set_interface_property kernel CMSIS_SVD_VARIABLES ""
set_interface_property kernel SVD_ADDRESS_GROUP ""

add_interface_port kernel kernel_write write Output 1
add_interface_port kernel kernel_read read Output 1
add_interface_port kernel kernel_writedata writedata Output 64
add_interface_port kernel kernel_readdata readdata Input 64
add_interface_port kernel kernel_byteenable byteenable Output 8
add_interface_port kernel kernel_readdatavalid readdatavalid Input 1
add_interface_port kernel kernel_waitrequest waitrequest Input 1
add_interface_port kernel kernel_address address Output 15




add_interface debug avalon end
set_interface_property debug associatedClock clk
set_interface_property debug ASSOCIATED_CLOCK clk
set_interface_property debug bitsPerSymbol 8 
set_interface_property debug associatedReset reset_n
set_interface_property debug ENABLED true
set_interface_property debug addressUnits WORDS
set_interface_property debug maximumPendingReadTransactions 1
add_interface_port debug debug_read read Input 1
add_interface_port debug debug_readdata readdata output 64
add_interface_port debug debug_readdatavalid readdatavalid output 1
add_interface_port debug debug_address address Input 9




# +-----------------------------------
# | connection point Avalon-MM Slave for cache hint config
# | 
# 
# connection point addr_cfg
# 
# | 
add_interface addr_cfg avalon end
set_interface_property addr_cfg associatedClock clk
set_interface_property addr_cfg ASSOCIATED_CLOCK clk
set_interface_property addr_cfg associatedReset reset_n
set_interface_property addr_cfg ENABLED true
set_interface_property addr_cfg addressUnits WORDS


add_interface_port addr_cfg addr_cfg_writedata writedata input 64
add_interface_port addr_cfg addr_cfg_address address input 9
add_interface_port addr_cfg addr_cfg_byteenable byteenable input 8
add_interface_port addr_cfg addr_cfg_write write input 1





add_interface irq interrupt start
#set_interface_property irq associatedAddressablePoint s1
set_interface_property irq associatedClock clk
set_interface_property irq associatedReset reset_n
add_interface_port irq kernel_irq irq Input 1


add_interface bp0 conduit start
add_interface_port bp0 write_pending write_pending output 1

# | 
# +-----------------------------------

# +-----------------------------------
# | Elaboration
# | 
proc elaborate {} {

}
# | 
# +-----------------------------------

