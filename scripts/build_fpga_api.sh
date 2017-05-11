#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

###clone aalsdk
rm -fr $AALSDK_SRC_PATH
#git clone /swip_apps/avl_vm/git_sync/git/cpt_sys_sw-fpga-sw.git -b develop $AALSDK_SRC_PATH
git clone /build/crauer/adapt/git/cpt_sys_sw-fpga-sw -b develop $AALSDK_SRC_PATH
cd $AALSDK_SRC_PATH

#build and install fpga api sw
rm -fr $AAL_INST_PATH
mkdir -p $AAL_INST_PATH
rm -fr $AAL_BUILD_PATH
mkdir -p $AAL_BUILD_PATH

cd $AAL_BUILD_PATH
cmake -DCMAKE_INSTALL_PREFIX=$AAL_INST_PATH $AALSDK_SRC_PATH
make -j16
make install
