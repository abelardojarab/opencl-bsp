#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/sim_common.sh

###untar aalsdk
rm -fr $BUILD_DIR/tmp
mkdir -p $BUILD_DIR/tmp

cd $BUILD_DIR/tmp
tar xzf $PACKAGE_DIR_PATH/aalsdk*.tar.gz
rm -fr $AALSDK_PATH
mv $BUILD_DIR/tmp/aalsdk* $AALSDK_PATH
cd $AALSDK_PATH
#patch -p2 < $SCRIPT_DIR_PATH/patches/aalsdk/ase_hacks.patch 
rm -fr $BUILD_DIR/tmp

#setup libttdl
rm -fr $LIB_TDL_PATH
mkdir -p $LIB_TDL_PATH
cd $LIB_TDL_PATH
rpm2cpio $PACKAGE_DIR_PATH/libtool-ltdl-2*x86_64.rpm | cpio -idmv
rpm2cpio $PACKAGE_DIR_PATH/libtool-ltdl-devel*x86_64.rpm | cpio -idmv

#build and install aal
rm -fr $AAL_INST_PATH
mkdir -p $AAL_INST_PATH

rm -fr $AAL_BUILD_PATH
mkdir -p $AAL_BUILD_PATH

cd $AAL_BUILD_PATH
export LIBRARY_PATH=$LIB_TDL_PATH/usr/lib64
export CPPFLAGS=-I$LIB_TDL_PATH/usr/include
$AALSDK_PATH/configure --prefix=$AAL_INST_PATH
make -j16
make install
