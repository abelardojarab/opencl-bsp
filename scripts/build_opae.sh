#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

#exit early and return error code if there is a problem
set -e

###clone opae src
rm -fr $OPAE_SRC_PATH
if [ "$OPAE_USE_GIT_ARCHIVE" == "1" ]; then
	echo "extracting opae from git archive..."
	mkdir -p $OPAE_SRC_PATH
	git archive --remote=$OPAE_GIT_PATH $OPAE_GIT_BRANCH | tar -x -C $OPAE_SRC_PATH
	cd $OPAE_SRC_PATH
else
	git clone $OPAE_GIT_PATH -b $OPAE_GIT_BRANCH $OPAE_SRC_PATH
fi

#build and install opae
rm -fr $OPAE_LOCAL_INST_PATH
rm -fr $OPAE_BUILD_PATH
mkdir -p $OPAE_LOCAL_INST_PATH
mkdir -p $OPAE_BUILD_PATH

cd $OPAE_BUILD_PATH
#might speed up compilation.  there was also an issue with hssi compile at one 
#point.  this hack disabled hssi stuff in opae build
#sed -i 's:add_subdirectory.tools/hssi.::' $OPAE_SRC_PATH/CMakeLists.txt 

#hack ASE for interrupts on non-DCP platform(because DCP mem model is slow)
sed -i -e 's/undef\s\+ASE_ENABLE_INTR_FEATURE/define  ASE_ENABLE_INTR_FEATURE/' $OPAE_SRC_PATH/ase/sw/ase_common.h

if [ "$OPENCL_ASE_SIM" == "1" ]; then
	CC=`which gcc` CXX=`which g++` cmake -DBUILD_ASE=ON -DCMAKE_INSTALL_PREFIX=$OPAE_LOCAL_INST_PATH $OPAE_SRC_PATH
else
	CC=`which gcc` CXX=`which g++` cmake -DCMAKE_INSTALL_PREFIX=$OPAE_LOCAL_INST_PATH $OPAE_SRC_PATH
fi
make -j16
make install

if [ "$OPENCL_ASE_SIM" == "1" ]; then
	#copy the ASE lib over the regular lib so that we don't have to relink our program
	cp $OPAE_LOCAL_INST_PATH/lib/libopae-c-ase.so $OPAE_LOCAL_INST_PATH/lib/libopae-c.so
fi
