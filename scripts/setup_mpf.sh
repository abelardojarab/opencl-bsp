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
#export LIBRARY_PATH=$LIB_TDL_PATH/usr/lib64
#export CPPFLAGS=-I$LIB_TDL_PATH/usr/include
export CMAKE_LIBRARY_PATH=$AALSDK/lib
export CMAKE_INCLUDE_PATH=$AALSDK/include
export CMAKE_PREFIX_PATH=$AALSDK
cp $PACKAGE_DIR_PATH/patches/mpf/CMakeLists.txt .
mkdir build
cd build
cmake -DCMAKE_REQUIRED_INCLUDES=$AALSDK/include ..
make -j16
cp libMPF*so $AOCL_BOARD_PACKAGE_ROOT/host/linux64/lib/

