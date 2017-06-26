#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

#exit early and return error code if there is a problem
set -e

cd $ROOT_PROJECT_PATH/source
make clean
make

if [ "$OPENCL_ASE_SIM" == "1" ]; then
	cp -f $AOCL_BOARD_PACKAGE_ROOT/ase/scripts/program $AOCL_BOARD_PACKAGE_ROOT/linux64/libexec/program
fi
