#!/bin/bash
#script to set up common variables

#get exact script path
COMMON_SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
COMMON_SCRIPT_DIR_PATH="$(dirname $COMMON_SCRIPT_PATH)"
export ROOT_PROJECT_PATH="$(dirname $COMMON_SCRIPT_DIR_PATH)"

BUILD_DIR=$ROOT_PROJECT_PATH/build
PACKAGE_DIR_PATH=$ROOT_PROJECT_PATH/packages

FPGA_API_SRC_PATH=$BUILD_DIR/fpga_api_src
FPGA_API_INST_PATH=$BUILD_DIR/fpga_api_inst

#TODO: don't export FPGA_API_BUILD_PATH once fpgaconf util is available with install
export FPGA_API_BUILD_PATH=$BUILD_DIR/fpga_api_build
if [ "$FPGA_API_PATH" == "" ]; then
	export FPGA_API_PATH=$FPGA_API_INST_PATH
fi
if [ "$FPGA_API_GIT_PATH" == "" ]; then
	if [ "$ARC_SITE" == "" ]; then
		FPGA_API_GIT_PATH=/storage/shared/tools/git/cpt_sys_sw-fpga-sw
	else
		FPGA_API_GIT_PATH=/swip_apps/avl_vm/git_sync/git/cpt_sys_sw-fpga-sw.git
	fi
fi
export FPGA_API_USE_GIT_ARCHIVE=1
export FPGA_API_GIT_BRANCH=develop

export AOCL_BOARD_PACKAGE_ROOT=$ROOT_PROJECT_PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ALTERAOCLSDKROOT/host/linux64/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$AOCL_BOARD_PACKAGE_ROOT/linux64/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$FPGA_API_PATH/lib
export QUARTUS_HOME=$QUARTUS_ROOTDIR
export ASE_WORKDIR=./temp_simulation/ase/work/
export MPF_INSTALL_PATH=$BUILD_DIR/mpf
export ASE_SRC_PATH=$FPGA_API_SRC_PATH/ase
export ACDS_ARC_RESOURCES="acl/17.0,acds/17.0,qedition/pro,adapt"
export SIM_ARC_RESOURCES="vcs,vcs-vcsmx-lic/vrtn-dev"
export SW_BUILD_ARC_RESOURCES="gcc/4.8.2,python,cmake/3.7.2,boost"

if [ "$OPENCL_ASE_SIM" == "1" ]; then
	export CL_CONTEXT_COMPILER_MODE_ALTERA=3
fi

setup_arc_for_script() {
	SCRIPT_ARGS="$@"
	
	ORG_SCRIPT_PATH=`readlink -f $0`
	
	if [ "$OPENCL_ASE_SIM" == "1" ]; then
		#check for vcs command, and get resources if needed
		which vcs &> /dev/null
		if [ "$?" != "0" ]; then
			echo warning: missing vcs command, using ARC
			arc shell $ACDS_ARC_RESOURCES,$SIM_ARC_RESOURCES,$SW_BUILD_ARC_RESOURCES -- $ORG_SCRIPT_PATH $SCRIPT_ARGS
			exit $?
		fi
	else
		#check for aocl command, and get resources if needed
		which aocl &> /dev/null
		if [ "$?" != "0" ]; then
			echo warning: missing aocl command, using ARC
			arc shell $ACDS_ARC_RESOURCES,$SW_BUILD_ARC_RESOURCES -- $ORG_SCRIPT_PATH $SCRIPT_ARGS
			exit $?
		fi
	fi
}

