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
	echo No OPAE_GIT_PATH defined, fetching from git...
	if [ "$ARC_SITE" == "" ]; then
		OPAE_GIT_PATH=/storage/shared/tools/git/opae-sdk-x.git
	else
		OPAE_GIT_PATH=/swip_apps/avl_vm/git_sync/git/opae-sdk-x.git
	fi
fi
echo "bsp_common.sh OPAE_GIT_PATH is $OPAE_GIT_PATH"

OPAE_USE_GIT_ARCHIVE="${OPAE_USE_GIT_ARCHIVE:-1}"
if [ "$OPAE_GIT_BRANCH" == "" ]; then
	#OPAE_GIT_BRANCH=master-x
	OPAE_GIT_BRANCH="rewind/master-x/2018-08-27"
fi
echo "bsp_common.sh OPAE_GIT_BRANCH is $OPAE_GIT_BRANCH"

export AOCL_BOARD_PACKAGE_ROOT=$ROOT_PROJECT_PATH
echo AOCL_BOARD_PACKAGE_ROOT is $AOCL_BOARD_PACKAGE_ROOT
echo ROOT_PROJECT_PATH is $ROOT_PROJECT_PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ALTERAOCLSDKROOT/host/linux64/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$AOCL_BOARD_PACKAGE_ROOT/linux64/lib

#TODO: remove this dependency from regtests
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPAE_INSTALL_PATH/lib:$OPAE_INSTALL_PATH/lib64

export QUARTUS_HOME=$QUARTUS_ROOTDIR
export ASE_WORKDIR=./temp_simulation/ase/work/
export MPF_INSTALL_PATH=$BUILD_DIR/mpf
export ASE_SRC_PATH=$OPAE_SRC_PATH/ase

if [ "$DCP_BSP_TARGET" == "" ]
then
	unset ACL_ACDS_VERSION_OVERRIDE
	ACDS_ARC_RESOURCES="acl/17.1.1,acds/swip_apps/avl_vm/acds_patched/17.1.1/acds,qedition/pro,adapt"
elif [ "$DCP_BSP_TARGET" == "dcp_s10" ] || [ "$DCP_BSP_TARGET" == "pac_s10_dc" ]
then
	ACDS_ARC_RESOURCES="acds/18.1/222,qedition/pro,adapt"
	if [ "$OPENCL_ASE_SIM" == "0" ]; then
		echo "For S10, we are using locally-patched version of acl in /data/dgroen/aocl_181_patch until we get a global resource of ACL 18.1 with the 0.16cl"
	fi
else
	unset ACL_ACDS_VERSION_OVERRIDE
	ACDS_ARC_RESOURCES="acl/17.1.1,acds/swip_apps/avl_vm/acds_patched/17.1.1/acds,qedition/pro,adapt"
fi
SIM_ARC_RESOURCES="vcs,vcs-vcsmx-lic/vrtn-dev"
SW_BUILD_ARC_RESOURCES="gcc/4.8.2,python,cmake/3.7.2,boost,doxygen/1.8.11"

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

