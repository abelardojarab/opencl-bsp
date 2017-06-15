#!/bin/bash
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

export OPENCL_ASE_SIM=0
export MINICLOUD=1

sudo chmod 666 /dev/intel-fpga-port.0 
source $SCRIPT_DIR_PATH/scripts/bsp_common.sh
echo $AOCL_BOARD_PACKAGE_ROOT
source $SCRIPT_DIR_PATH/scripts/setup_packages.sh

source /storage/shared/home_directories/crauer/opencl_install/aclrte/init_opencl.sh

