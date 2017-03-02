#!/bin/bash
#script to set up common variables

#get exact script path
COMMON_SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
COMMON_SCRIPT_DIR_PATH="$(dirname $COMMON_SCRIPT_PATH)"
export ROOT_PROJECT_PATH="$(dirname $COMMON_SCRIPT_DIR_PATH)"

BUILD_DIR=$ROOT_PROJECT_PATH/build
AALSDK_PATH=$BUILD_DIR/aalsdk_src
AAL_INST_PATH=$BUILD_DIR/aalsdk
AAL_BUILD_PATH=$BUILD_DIR/aalsdk_build
export LIB_TDL_PATH=$BUILD_DIR/lib_tdl
PACKAGE_DIR_PATH=$ROOT_PROJECT_PATH/packages

if [ "$AALSDK" == "" ]; then
	export AALSDK=$AAL_INST_PATH
fi
export AOCL_BOARD_PACKAGE_ROOT=$ROOT_PROJECT_PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ALTERAOCLSDKROOT/host/linux64/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$AOCL_BOARD_PACKAGE_ROOT/host/linux64/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$AALSDK/lib
export CL_CONTEXT_COMPILER_MODE_ALTERA=3
export QUARTUS_HOME=$QUARTUS_ROOTDIR
export ASE_WORKDIR=./temp_simulation/ase/work/
export MPF_INSTALL_PATH=$BUILD_DIR/mpf
export ASE_SRC_PATH=$AALSDK_PATH/ase

export BLUE_BITS_SOF_DIR_PATH=/net/sj-crauer-l/build2/crauer/adapt/opencl_project/git/afu_template_pll_sysclk/blue_bits
export BLUE_BITS_QDB_FILE_PATH=/net/sj-crauer-l/build2/crauer/adapt/opencl_project/git/afu_template_pll_sysclk/dcp.qdb

