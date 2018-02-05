#!/bin/bash
#script to set up common variables

#get exact script path
COMMON_SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
COMMON_SCRIPT_DIR_PATH="$(dirname $COMMON_SCRIPT_PATH)"
export ROOT_PROJECT_PATH="$(dirname $COMMON_SCRIPT_DIR_PATH)"

BUILD_DIR=$ROOT_PROJECT_PATH/build
PACKAGE_DIR_PATH=$ROOT_PROJECT_PATH/packages

OPAE_SRC_PATH=$BUILD_DIR/opae_src
OPAE_LOCAL_INST_PATH=$BUILD_DIR/opae_inst
OPAE_BUILD_PATH=$BUILD_DIR/opae_build

if [ "$OPAE_INSTALL_PATH" == "" ]; then
	export OPAE_INSTALL_PATH=$OPAE_LOCAL_INST_PATH
fi
if [ "$OPAE_GIT_PATH" == "" ]; then
	if [ "$ARC_SITE" == "" ]; then
		OPAE_GIT_PATH=/storage/shared/tools/git/opae-sdk-x.git
	else
		OPAE_GIT_PATH=/swip_apps/avl_vm/git_sync/git/opae-sdk-x.git
	fi
fi

OPAE_USE_GIT_ARCHIVE="${OPAE_USE_GIT_ARCHIVE:-1}"
if [ "$OPAE_GIT_BRANCH" == "" ]; then
	OPAE_GIT_BRANCH=master-x
fi

export AOCL_BOARD_PACKAGE_ROOT=$ROOT_PROJECT_PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ALTERAOCLSDKROOT/host/linux64/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$AOCL_BOARD_PACKAGE_ROOT/linux64/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPAE_INSTALL_PATH/lib
export QUARTUS_HOME=$QUARTUS_ROOTDIR
export ASE_WORKDIR=./temp_simulation/ase/work/
export MPF_INSTALL_PATH=$BUILD_DIR/mpf
export ASE_SRC_PATH=$OPAE_SRC_PATH/ase
ACDS_ARC_RESOURCES="acl/17.1.1,acds/17.1.1,qedition/pro,adapt"
SIM_ARC_RESOURCES="vcs,vcs-vcsmx-lic/vrtn-dev"
SW_BUILD_ARC_RESOURCES="gcc/4.8.2,python,cmake/3.7.2,boost"

if [ "$OPENCL_ASE_SIM" == "1" ]; then
	export CL_CONTEXT_COMPILER_MODE_ALTERA=3
	export DCP_BYPASS_OPENCL_RUN_SCRIPT="sim_compile.sh"
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

