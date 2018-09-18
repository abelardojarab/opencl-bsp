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
rm -fr build

rm -fr $ROOT_PROJECT_PATH/linux64/lib
rm -f $ROOT_PROJECT_PATH/linux64/libexec/diagnose
rm -f $ROOT_PROJECT_PATH/linux64/libexec/program

mkdir build && cd build
echo "build_mmd.sh: inside build, before cmake"
CC=`which gcc` CXX=`which g++` cmake -DUSE_MEMCPY_S=ON -DOPENCL_ASE_SIM=$SET_ASE -DCMAKE_INSTALL_PREFIX=$ROOT_PROJECT_PATH/linux64 $ROOT_PROJECT_PATH/source
echo "build_mmd.sh: after cmake, before make && make install"
make && make install
echo "build_mmd.sh: after make && make install"

if [ "$OPENCL_ASE_SIM" == "1" ]; then
	rm -f $AOCL_BOARD_PACKAGE_ROOT/linux64/libexec/program
	ln -s $AOCL_BOARD_PACKAGE_ROOT/ase/scripts/program $AOCL_BOARD_PACKAGE_ROOT/linux64/libexec/program
fi
