#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

#exit early and return error code if there is a problem
set -e

SET_ASE="OFF"
if [ "$OPENCL_ASE_SIM" == "1" ]; then
   SET_ASE="ON"
fi

cd $ROOT_PROJECT_PATH/source
mkdir build && cd build
CC=`which gcc` CXX=`which g++` cmake -DOPENCL_ASE_SIM=$SET_ASE -DCMAKE_INSTALL_PREFIX=$ROOT_PROJECT_PATH/linux64 $ROOT_PROJECT_PATH/source
make && make install

if [ "$OPENCL_ASE_SIM" == "1" ]; then
	cp -f $AOCL_BOARD_PACKAGE_ROOT/ase/scripts/program $AOCL_BOARD_PACKAGE_ROOT/linux64/libexec/program
fi
