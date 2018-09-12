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
echo "This is the run.sh script."

#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
SCRIPT_DIR_PARENT_PATH="$(dirname $SCRIPT_DIR_PATH)"

cd $SCRIPT_DIR_PATH

#test packager bin first to make sure it is available and working and fail
#early if it can't run.
#it would be frustrating to find out at the end of the compilation
ADAPT_PACKAGER_BIN="python ./tools/packager.pyz"
FLOW_SUCCESS=1
$ADAPT_PACKAGER_BIN > /dev/null
FLOW_SUCCESS=$?
if [ $FLOW_SUCCESS != 0 ]; then
	echo "ERROR: packager tool failed to run.  Check installation.  Aborting compilation!"
	exit 1
fi

#make sure bbs files exist
if [ ! -f "dcp.qdb" ]; then
	echo "ERROR: BSP is not setup"
fi

#copy quartus.ini
cp ../quartus.ini .

#import opencl kernel files
quartus_sh -t scripts/import_opencl_kernel.tcl 

#check for bypass/alternative flows
if [ "$DCP_BYPASS_OPENCL_RUN_SCRIPT" != "" ]; then
	sh $DCP_BYPASS_OPENCL_RUN_SCRIPT
	exit $?
fi

echo "which quartus_sh:"
which quartus_sh

#add BBBs to quartus pr project
quartus_sh -t add_bbb_to_pr_project.tcl

cp ../afu_opencl_kernel.qsf .

echo "qsys-generate board.qsys"
qsys-generate -syn --quartus-project=dcp --rev=afu_opencl_kernel board.qsys
# adding board.qsys and corresponding .ip parameterization files to opencl_bsp_ip.qsf
qsys-archive --quartus-project=dcp --rev=afu_opencl_kernel --add-to-project board.qsys

# generate kernel_system.qsys 
# and add Qsys Pro generated files to "afu_opencl_kernel.qsf"
echo "qsys-generate kernel_system.qsys"
qsys-generate -syn --quartus-project=dcp --rev=afu_opencl_kernel kernel_system.qsys
qsys-archive --quartus-project=dcp --rev=afu_opencl_kernel --add-to-project kernel_system.qsys

#append kernel_system qsys/ip assignments to afu_default revision
echo "removing kernel_system_qsf_append.txt and recreating it based on afu_opencl_kernel.qsf"
rm -f kernel_system_qsf_append.txt
echo >> kernel_system_qsf_append.txt
grep -A10000 OPENCL_KERNEL_ASSIGNMENTS_START_HERE afu_opencl_kernel.qsf >> kernel_system_qsf_append.txt
echo >> kernel_system_qsf_append.txt

cat kernel_system_qsf_append.txt >> afu_default.qsf
echo "copied kernel_system_qsf_append.txt to the end of afu_default.qsf"
echo "kernel_system_qsf_append.txt is cat'd below:"
cat kernel_system_qsf_append.txt
echo "end of kernel_system_qsf_append.txt"

# compile project
# =====================
quartus_sh -t s10_partial_reconfig/flow.tcl -nobasecheck -setup_script s10_partial_reconfig/setup.tcl -impl afu_default
FLOW_SUCCESS=$?

# Report Timing
# =============
quartus_sh -t scripts/adjust_plls_mcp.tcl
if [ $FLOW_SUCCESS -eq 1 ]
then
    echo "ERROR: pll timing script failed."
    exit 1
fi

#run packager tool to create GBS
echo "run.sh: Running packager tool to create GBS."
BBS_ID_FILE="fme-ifc-id.txt"
if [ -f "$BBS_ID_FILE" ]; then
	FME_IFC_ID=`cat $BBS_ID_FILE`
    echo "run.sh: FME_IFC_ID/BBS_ID_FILE is: "
    cat $BBS_ID_FILE
else
    echo "ERROR: fme id not found."
    exit 1
fi

PLL_METADATA=""
PLL_METADATA_FILE="pll_metadata.txt"
if [ -f "$PLL_METADATA_FILE" ]; then
	PLL_METADATA=`cat $PLL_METADATA_FILE`
    echo "run.sh: PLL_METADATA/PLL_METADATA_FILE is: "
    cat $PLL_METADATA_FILE
fi

#check for generated rbf and gbs files
if [ ! -f ./output_files/afu_default.green_region.rbf ]; then
    echo "ERROR: ./output_files/afu_default.green_region.rbf is missing!"
    echo "If using a VID-enabled part, ensure you have the VID settings in the qsf file,"
    echo "or you use the quartus.ini workaround."
    exit 1
fi

rm -f afu.gbs
$ADAPT_PACKAGER_BIN create-gbs \
	--rbf ./output_files/afu_default.green_region.rbf \
	--gbs ./output_files/afu_default.gbs \
	--afu-json opencl_afu.json \
	--set-value \
		interface-uuid:$FME_IFC_ID \
		$PLL_METADATA

echo "run.sh: Done packager..."

rm -rf fpga.bin

gzip -9c ./output_files/afu_default.gbs > afu_default.gbs.gz
aocl binedit fpga.bin create
aocl binedit fpga.bin add .acl.gbs.gz ./afu_default.gbs.gz

echo "run.sh: done zipping up the gbs into gbs.gz, and creating fpga.bin"

if [ -f afu_default.failing_clocks.rpt ]; then
	aocl binedit fpga.bin add .failing_clocks.rpt ./afu_default.failing_clocks.rpt
	cp ./afu_default.failing_clocks.rpt ../
    echo "run.sh: done appending failing clocks report to fpga.bin"
fi

if [ -f afu_default.failing_paths.rpt ]; then
	aocl binedit fpga.bin add .failing_paths.rpt ./afu_default.failing_paths.rpt
	cp ./afu_default.failing_paths.rpt ../
    echo "run.sh: done appending failing paths report to fpga.bin"
fi

if [ ! -f fpga.bin ]; then
	echo "ERROR: no fpga.bin found.  FPGA compilation failed!"
	exit 1
fi

#copy fpga.bin to parent directory so aoc flow can find it
cp fpga.bin ../
cp acl_quartus_report.txt ../

echo ""
echo "==========================================================================="
echo "OpenCL AFU compilation complete"
echo "==========================================================================="
echo ""
