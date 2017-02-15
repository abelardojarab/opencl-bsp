# TCL File Generated by Component Editor 15.0
# Fri Jul 10 15:11:58 EDT 2015
# DO NOT MODIFY


# 
# rr_arb "rr_arb" v1.0
#  2015.07.10.15:11:58
# 
# 

# 
# request TCL package from ACDS 15.0
# 
package require -exact qsys 15.0


# 
# module rr_arb
# 
set_module_property DESCRIPTION ""
set_module_property NAME rr_arb
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME rr_arb
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL rr_arb
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file rr_arb.v VERILOG PATH rr_arb.v TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL rr_arb
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file rr_arb.v VERILOG PATH rr_arb.v


# 
# parameters
# 


# 
# display items
# 


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clk clk Input 1


# 
# connection point reset
# 
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
set_interface_property reset EXPORT_OF ""
set_interface_property reset PORT_NAME_MAP ""
set_interface_property reset CMSIS_SVD_VARIABLES ""
set_interface_property reset SVD_ADDRESS_GROUP ""

add_interface_port reset reset reset Input 1


# 
# connection point avmm_w
# 
add_interface avmm_w avalon end
set_interface_property avmm_w addressUnits SYMBOLS
set_interface_property avmm_w associatedClock clock
set_interface_property avmm_w associatedReset reset
set_interface_property avmm_w bitsPerSymbol 8
set_interface_property avmm_w burstOnBurstBoundariesOnly false
set_interface_property avmm_w burstcountUnits SYMBOLS
set_interface_property avmm_w explicitAddressSpan 0
set_interface_property avmm_w holdTime 0
set_interface_property avmm_w linewrapBursts false
set_interface_property avmm_w maximumPendingReadTransactions 0
set_interface_property avmm_w maximumPendingWriteTransactions 0
set_interface_property avmm_w readLatency 0
set_interface_property avmm_w readWaitTime 1
set_interface_property avmm_w setupTime 0
set_interface_property avmm_w timingUnits Cycles
set_interface_property avmm_w writeWaitTime 0
set_interface_property avmm_w ENABLED true
set_interface_property avmm_w EXPORT_OF ""
set_interface_property avmm_w PORT_NAME_MAP ""
set_interface_property avmm_w CMSIS_SVD_VARIABLES ""
set_interface_property avmm_w SVD_ADDRESS_GROUP ""

add_interface_port avmm_w avmm_w_address address Input 64
add_interface_port avmm_w avmm_w_waitrequest waitrequest Output 1
add_interface_port avmm_w avmm_w_burstcount burstcount Input 1
add_interface_port avmm_w avmm_w_byteenable byteenable Input 64
add_interface_port avmm_w avmm_w_write write Input 1
add_interface_port avmm_w avmm_w_writedata writedata Input 512
set_interface_assignment avmm_w embeddedsw.configuration.isFlash 0
set_interface_assignment avmm_w embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment avmm_w embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment avmm_w embeddedsw.configuration.isPrintableDevice 0


# 
# connection point avmm_r
# 
add_interface avmm_r avalon end
set_interface_property avmm_r addressUnits SYMBOLS
set_interface_property avmm_r associatedClock clock
set_interface_property avmm_r associatedReset reset
set_interface_property avmm_r bitsPerSymbol 8
set_interface_property avmm_r burstOnBurstBoundariesOnly false
set_interface_property avmm_r burstcountUnits SYMBOLS
set_interface_property avmm_r explicitAddressSpan 0
set_interface_property avmm_r holdTime 0
set_interface_property avmm_r linewrapBursts false
set_interface_property avmm_r maximumPendingReadTransactions 512
set_interface_property avmm_r maximumPendingWriteTransactions 0
set_interface_property avmm_r readLatency 0
set_interface_property avmm_r readWaitTime 1
set_interface_property avmm_r setupTime 0
set_interface_property avmm_r timingUnits Cycles
set_interface_property avmm_r writeWaitTime 0
set_interface_property avmm_r ENABLED true
set_interface_property avmm_r EXPORT_OF ""
set_interface_property avmm_r PORT_NAME_MAP ""
set_interface_property avmm_r CMSIS_SVD_VARIABLES ""
set_interface_property avmm_r SVD_ADDRESS_GROUP ""

add_interface_port avmm_r avmm_r_address address Input 64
add_interface_port avmm_r avmm_r_waitrequest waitrequest Output 1
add_interface_port avmm_r avmm_r_burstcount burstcount Input 1
add_interface_port avmm_r avmm_r_read read Input 1
add_interface_port avmm_r avmm_r_readdata readdata Output 512
add_interface_port avmm_r avmm_r_readdatavalid readdatavalid Output 1
set_interface_assignment avmm_r embeddedsw.configuration.isFlash 0
set_interface_assignment avmm_r embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment avmm_r embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment avmm_r embeddedsw.configuration.isPrintableDevice 0


# 
# connection point avalon_master
# 
add_interface avalon_master avalon start
set_interface_property avalon_master addressUnits SYMBOLS
set_interface_property avalon_master associatedClock clock
set_interface_property avalon_master associatedReset reset
set_interface_property avalon_master bitsPerSymbol 8
set_interface_property avalon_master burstOnBurstBoundariesOnly false
set_interface_property avalon_master burstcountUnits WORDS
set_interface_property avalon_master doStreamReads false
set_interface_property avalon_master doStreamWrites false
set_interface_property avalon_master holdTime 0
set_interface_property avalon_master linewrapBursts false
set_interface_property avalon_master maximumPendingReadTransactions 0
set_interface_property avalon_master maximumPendingWriteTransactions 0
set_interface_property avalon_master readLatency 0
set_interface_property avalon_master readWaitTime 1
set_interface_property avalon_master setupTime 0
set_interface_property avalon_master timingUnits Cycles
set_interface_property avalon_master writeWaitTime 0
set_interface_property avalon_master ENABLED true
set_interface_property avalon_master EXPORT_OF ""
set_interface_property avalon_master PORT_NAME_MAP ""
set_interface_property avalon_master CMSIS_SVD_VARIABLES ""
set_interface_property avalon_master SVD_ADDRESS_GROUP ""

add_interface_port avalon_master qpi_slave_address address Output 64
add_interface_port avalon_master qpi_slave_write write Output 1
add_interface_port avalon_master qpi_slave_read read Output 1
add_interface_port avalon_master qpi_slave_readdata readdata Input 512
add_interface_port avalon_master qpi_slave_writedata writedata Output 512
add_interface_port avalon_master qpi_slave_byteenable byteenable Output 64
add_interface_port avalon_master qpi_slave_readdatavalid readdatavalid Input 1
add_interface_port avalon_master qpi_slave_waitrequest waitrequest Input 1

