#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

###clone FPGA_API_PATH
rm -fr $FPGA_API_SRC_PATH
#git clone /swip_apps/avl_vm/git_sync/git/cpt_sys_sw-fpga-sw.git -b develop $FPGA_API_SRC_PATH
git clone /build/crauer/adapt/git/cpt_sys_sw-fpga-sw -b develop $FPGA_API_SRC_PATH
cd $FPGA_API_SRC_PATH

#build and install fpga api sw
rm -fr $FPGA_API_INST_PATH
mkdir -p $FPGA_API_INST_PATH
rm -fr $FPGA_API_BUILD_PATH
mkdir -p $FPGA_API_BUILD_PATH

cd $FPGA_API_BUILD_PATH
cmake -DCMAKE_INSTALL_PREFIX=$FPGA_API_INST_PATH $FPGA_API_SRC_PATH
make -j16
make install
