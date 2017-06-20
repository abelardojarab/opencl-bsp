#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

#exit early and return error code if there is a problem
set -e

###clone FPGA_API_PATH
rm -fr $FPGA_API_SRC_PATH
if [ "$FPGA_API_USE_GIT_ARCHIVE" == "1" ]; then
	echo "extracting fpga api from git archive..."
	mkdir -p $FPGA_API_SRC_PATH
	git archive --remote=$FPGA_API_GIT_PATH $FPGA_API_GIT_BRANCH | tar -x -C $FPGA_API_SRC_PATH
	cd $FPGA_API_SRC_PATH
else
	git clone $FPGA_API_GIT_PATH -b $FPGA_API_GIT_BRANCH $FPGA_API_SRC_PATH
fi

#build and install fpga api sw
rm -fr $FPGA_API_INST_PATH
rm -fr $FPGA_API_BUILD_PATH
mkdir -p $FPGA_API_INST_PATH
mkdir -p $FPGA_API_BUILD_PATH

cd $FPGA_API_BUILD_PATH
if [ "$OPENCL_ASE_SIM" == "1" ]; then
	CC=`which gcc` CXX=`which g++` cmake -DBUILD_ASE=ON -DCMAKE_INSTALL_PREFIX=$FPGA_API_INST_PATH $FPGA_API_SRC_PATH
else
	CC=`which gcc` CXX=`which g++` cmake -DCMAKE_INSTALL_PREFIX=$FPGA_API_INST_PATH $FPGA_API_SRC_PATH
fi
make -j16
make install

if [ "$OPENCL_ASE_SIM" == "1" ]; then
	#copy the ASE lib over the regular lib so that we don't have to relink our program
	cp $FPGA_API_INST_PATH/lib/libfpga-ASE.so $FPGA_API_INST_PATH/lib/libfpga.so
fi
