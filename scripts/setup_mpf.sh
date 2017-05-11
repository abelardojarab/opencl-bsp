#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

###untar mpf
rm -fr $BUILD_DIR/tmp
mkdir -p $BUILD_DIR/tmp
rm -fr $MPF_INSTALL_PATH

cd $BUILD_DIR/tmp
tar xzf $PACKAGE_DIR_PATH/cci-mpf-*.tar.gz
cd ..
mv $BUILD_DIR/tmp $MPF_INSTALL_PATH
cd $MPF_INSTALL_PATH

###compile mpf sw and copy it to dest
cd $MPF_INSTALL_PATH/sw
#TODO: remove lib tdl and get this working with fpga-sw
export LIBRARY_PATH=$LIB_TDL_PATH/usr/lib64
export CPPFLAGS=-I$LIB_TDL_PATH/usr/include
make -j16 prefix=$FPGA_API_PATH
cp libMPF*so $AOCL_BOARD_PACKAGE_ROOT/host/linux64/lib/

