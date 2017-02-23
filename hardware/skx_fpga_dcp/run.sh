#!/bin/bash

if [ "$OPENCL_ASE_SIM" == "1" ]; then
	sh sim_compile.sh
	exit $?
fi

FLOW_SUCCESS=1

# Copy Blue bitstream library 
# ===========================
echo "Restoring Blue BS lib files"
echo "==========================="
#TODO: copy files
cp -fr $BLUE_BITS_SOF_DIR_PATH blue_bits
cp $BLUE_BITS_QDB_FILE_PATH dcp.qdb

# generate board.qsys
qsys-generate --synthesis=VERILOG --family="Arria 10" --part=10AX115N3F40E2SG  kernel_system.qsys
qsys-generate --synthesis=VERILOG --family="Arria 10" --part=10AX115N3F40E2SG  board.qsys

# compile project
# =====================
quartus_sh -t a10_partial_reconfig.tcl -setup_script pr_setup.tcl -impl afu_fit
FLOW_SUCCESS=$?

# Report Timing
# =============
if [ $FLOW_SUCCESS -eq 0 ]
then
    #quartus_sta --do_report_timing dcp -c afu_fit
	#quartus_sh -t scripts/adjust_plls_mcp.tcl
	echo "skipping timing flow for now..."
else
    echo "Persona compilation failed"
    exit 1
fi

#run packager tool to create GBS
packager create-gbs --rbf ./output_files/afu_fit.green_region.rbf --gbs ./output_files/afu_fit.gbs --no-metadata
cp ./output_files/afu_fit.gbs fpga.bin

if [ ! -f fpga.bin ]; then
	echo "FPGA compilation failed!"
	exit 1
fi

echo ""
echo "==========================================================================="
echo "SKX-P PR AFU compilation complete"
echo "*** DEFAULT (uClk_usr, uClk_usrDiv2) is (312.5 MHz, 156.25 MHz) ****"
echo "AFU gbs file located at output_files/afu_fit.gbs"
echo "Use this gbs file with aliconfafu utility to load PR bitstream"
echo "==========================================================================="
echo ""
