#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

#exit early and return error code if there is a problem
set -e

#check for FPGA API
if [ ! -d "$FPGA_API_PATH" ]; then
  echo "FPGA_API_PATH does not exist.  need to build"
  sh $SCRIPT_DIR_PATH/build_fpga_api.sh
fi

#TODO: reenable MPF build
#check for MPF
#if [ ! -d "$MPF_INSTALL_PATH" ]; then
#  echo "MPF does not exist.  need to build"
#  sh $SCRIPT_DIR_PATH/setup_mpf.sh
#fi

#check for MMD
if [ ! -f "$AOCL_BOARD_PACKAGE_ROOT/linux64/lib/libaltera_ccip_mmd.so" ]; then
  echo "MMD does not exist.  need to build"
  sh $SCRIPT_DIR_PATH/build_mmd.sh
fi

echo "all packages are setup."
