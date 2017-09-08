#!/bin/bash

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

ADAPT_PACKAGER_BIN=$ADAPT_DEST_ROOT/bin/packager
if [ "$ADAPT_DEST_ROOT" == "" ]; then
	ADAPT_PACKAGER_BIN="python ./tools/packager.pyz"
fi

#test packager bin
FLOW_SUCCESS=1
$ADAPT_PACKAGER_BIN > /dev/null
FLOW_SUCCESS=$?
if [ $FLOW_SUCCESS != 0 ]; then
	echo "ERROR: packager tool failed to run.  Check installation.  Aborting compilation!"
	exit 1
fi

#check for bypass/alternative flows
if [ "$DCP_BYPASS_OPENCL_RUN_SCRIPT" != "" ]; then
	sh $DCP_BYPASS_OPENCL_RUN_SCRIPT
	exit $?
fi

# Copy Blue bitstream library 
# ===========================
echo "Restoring Blue BS lib files"
echo "==========================="

if [ -f "dcp.qdb" ]; then
	echo "INFO: blue bits already imported"
else
	sh import_blue_bits.sh
	FLOW_SUCCESS=$?
	if [ $FLOW_SUCCESS != 0 ]; then
		echo "ERROR: Blue bits import failed!"
		exit 1
	fi
fi

#need to design directory with timing files so that they are the same as blue 
#bits
rsync -rvua design/ ../design

# generate board.qsys
qsys-generate --synthesis=VERILOG -qpf=dcp -c=afu_synth kernel_system.qsys
qsys-generate --synthesis=VERILOG -qpf=dcp -c=afu_synth board.qsys
# compile project
# =====================
quartus_sh -t a10_partial_reconfig/flow.tcl -setup_script a10_partial_reconfig/setup.tcl -impl afu_fit
FLOW_SUCCESS=$?

# Report Timing
# =============
if [ $FLOW_SUCCESS -eq 0 ]
then
	quartus_sh -t scripts/adjust_plls_mcp.tcl
	quartus_sh -t scripts/create_afu_quartus_report.tcl dcp afu_fit
else
    echo "Persona compilation failed"
    exit 1
fi

#run packager tool to create GBS
BBS_ID_FILE="fme-ifc-id.txt"
if [ -f "$BBS_ID_FILE" ]; then
	FME_IFC_ID=`cat $BBS_ID_FILE`
else
	FME_IFC_ID="01234567-89AB-CDEF-0123-456789ABCDEF"
fi

PLL_METADATA=""
PLL_METADATA_FILE="pll_metadata.txt"
if [ -f "$PLL_METADATA_FILE" ]; then
	PLL_METADATA=`cat $PLL_METADATA_FILE`
fi

rm -f afu.gbs
$ADAPT_PACKAGER_BIN create-gbs \
	--rbf ./output_files/afu_fit.green_region.rbf \
	--gbs ./output_files/afu_fit.gbs \
	--afu-json opencl_afu.json \
	--set-value \
		interface-uuid:$FME_IFC_ID \
		$PLL_METADATA

rm -rf fpga.bin

gzip -9c ./output_files/afu_fit.gbs > afu_fit.gbs.gz
aocl binedit fpga.bin create
aocl binedit fpga.bin add .acl.gbs.gz ./afu_fit.gbs.gz

if [ -f afu_quartus_report.txt ]; then
	aocl binedit fpga.bin add .afu_quartus_report.txt ./afu_quartus_report.txt
fi

if [ -f afu_fit.failing_clocks.rpt ]; then
	aocl binedit fpga.bin add .failing_clocks.rpt ./afu_fit.failing_clocks.rpt
fi

if [ -f afu_fit.failing_paths.rpt ]; then
	aocl binedit fpga.bin add .failing_paths.rpt ./afu_fit.failing_paths.rpt
fi

if [ ! -f fpga.bin ]; then
	echo "FPGA compilation failed!"
	exit 1
fi

echo ""
echo "==========================================================================="
echo "SKX-P PR AFU compilation complete"
echo "*** DEFAULT (uClk_usr, uClk_usrDiv2) is (312.5 MHz, 156.25 MHz) ****"
echo "AFU gbs file located at output_files/afu_fit.gbs"
echo "==========================================================================="
echo ""
