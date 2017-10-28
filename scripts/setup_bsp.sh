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

#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
MAIN_SRC_PATH="$(dirname $SCRIPT_DIR_PATH)"

BSP_DIR="$MAIN_SRC_PATH/hardware/dcp_a10"
PLATFORM="dcp_1.0-skx"

[ ! -z "$1" ] && BSP_DIR="$1"
[ ! -z "$2" ] && PLATFORM="$2"

if [ "$BSP_DIR" == "all" ]; then
	
	set -e 
	for i in `find $MAIN_SRC_PATH/hardware/ -name board_spec.xml`
	do
		BSP_DIR=`dirname $i`
		$SCRIPT_PATH $BSP_DIR $PLATFORM
		echo $BSP_DIR
	done
exit 0
fi

echo BSP Setup: BSP_DIR=$BSP_DIR with PLATFORM=$PLATFORM

cd $BSP_DIR

if [ -z "$ADAPT_DEST_ROOT" ]; then
	echo "ERROR: ADAPT_DEST_ROOT is not set.  Cannot find platform binaries for PR flow"
	exit 1
fi

FULL_PLATFORM_PATH=$ADAPT_DEST_ROOT/platform/$PLATFORM

echo "INFO: importing blue bits from platform path: $FULL_PLATFORM_PATH"

copy_platform_file() {
	SRC_FILE=$1
	DEST_PATH=$2
	
	if [ ! -f "$SRC_FILE" ]; then
		echo "ERROR: $SRC_FILE not found"
		exit 1
	fi
	
	cp -L $SRC_FILE $DEST_PATH
}

copy_platform_file_no_err() {
	SRC_FILE=$1
	DEST_PATH=$2
	
	if [ -f "$SRC_FILE" ]; then
		cp -L $SRC_FILE $DEST_PATH
	else
		echo "WARNING: $SRC_FILE not found"
	fi
}

update_qsf_for_opencl_afu()
{
	QSF_FILE=$1
	chmod +w $QSF_FILE
	
	echo >> $QSF_FILE
	echo >> $QSF_FILE
	echo "# AFU  section - User AFU RTL goes here" >> $QSF_FILE
	echo "# =============================================" >> $QSF_FILE
	echo "#" >> $QSF_FILE
	echo "# AFU + MPF IPs" >> $QSF_FILE
	echo "source afu_ip.qsf" >> $QSF_FILE
	
	#move afu from ../afu to ./afu
	sed -i -e 's;../afu/;./afu/;g' $QSF_FILE
}

update_qpf_for_opencl_afu()
{
	QPF_FILE=$1
	chmod +w $QPF_FILE
	
	sed -i '/PROJECT_REVISION/d' $QPF_FILE
	echo >> $QPF_FILE
	echo >> $QPF_FILE
	echo '#YOU MUST PUT SYNTH REVISION FIRST SO THAT AOC WILL DEFAULT TO THAT WITH qsys-script!' >> $QPF_FILE
	echo 'PROJECT_REVISION = "afu_synth"' >> $QPF_FILE
	echo 'PROJECT_REVISION = "afu_fit"' >> $QPF_FILE
	echo 'PROJECT_REVISION = "dcp"' >> $QPF_FILE
}

rm -fr "output_files"
mkdir "output_files"
mkdir -p "afu"
mkdir -p "afu/interfaces"

set -e


cp -Lr $FULL_PLATFORM_PATH/lib/* .

#copy emptry afu src files
cp -Lr $FULL_PLATFORM_PATH/empty_afu/afu/ .
cp -Lr $FULL_PLATFORM_PATH/empty_afu/build/* .

update_qsf_for_opencl_afu afu_synth.qsf
update_qsf_for_opencl_afu afu_fit.qsf
update_qpf_for_opencl_afu dcp.qpf

#clean up unneeded files
rm -fv *.stp
rm -fv a10_partial_reconfig/import_bbs_sdc.tcl

#add packager to opencl bsp to make bsp easier to use
mkdir -p "tools"
copy_platform_file "$ADAPT_DEST_ROOT/tools/packager/packager.pyz"         "./tools/packager.pyz"

#unzip pr artifacts
rm -rf design
tar zxf pr_design_artifacts.tar.gz
rm -f pr_design_artifacts.tar.gz

#setup sim stuff if needed
if [ "$OPENCL_ASE_SIM" == "1" ]; then
	cp -Lr $MAIN_SRC_PATH/ase/bsp/* .
fi
