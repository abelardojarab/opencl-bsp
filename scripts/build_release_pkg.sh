#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

#we don't build release packages for simulation
export OPENCL_ASE_SIM=0

#setup common variables
. $SCRIPT_DIR_PATH/bsp_common.sh

#exit early and return error code if there is a problem
set -e

#RELEASE SCRIPT VARIABLES
#git archive --format=tar HEAD | gzip -9 > git_archive_`date +%m%d%y`.tar.gz
TOP_GIT_COMMIT=`cd $SCRIPT_DIR_PATH; git rev-parse --short HEAD`
RELEASE_TAR_PATH=$RELEASE_BUILD_DIR/dcp_opencl_bsp_${TOP_GIT_COMMIT}_`date +%m%d%y_%H%M%S`.tar.gz
PACKAGE_TEST_DIR=$RELEASE_BUILD_DIR/test_pkg
BSP_DIR_NAME=dcp_opencl_bsp
REPO_VERSION_FILE=$RELEASE_BUILD_DIR/repo_version.txt

if [ "$1" != "" ]; then
	export BSP_BOARD_TARGET=$1
fi

if [ "$BSP_BOARD_TARGET" == "" ]; then
	export BSP_BOARD_TARGET=skx_fpga_dcp_ddr
fi

#use a stable OPAE release
export OPAE_GIT_BRANCH=release/0.3.0

##############################################################################

#clean up existing build
#rm -fr $BUILD_DIR
rm -fr $RELEASE_BUILD_DIR

$SCRIPT_DIR_PATH/setup_packages.sh

echo "Building Release packager for '$BSP_BOARD_TARGET'"

#setup release dir
mkdir $RELEASE_BUILD_DIR
mkdir $RELEASE_BUILD_DIR/$BSP_DIR_NAME

#create log for release
echo repo information > $REPO_VERSION_FILE
echo git repository path: $ROOT_PROJECT_PATH >> $REPO_VERSION_FILE
echo git branch: $ROOT_PROJECT_PATH >> $REPO_VERSION_FILE
echo last commit log: >> $REPO_VERSION_FILE
cd $ROOT_PROJECT_PATH
git log -n 1 >> $REPO_VERSION_FILE

#setup bsp dir
cp -R $ROOT_PROJECT_PATH/board_env.xml $RELEASE_BUILD_DIR/$BSP_DIR_NAME/
sed -i -e "s/skx_fpga_dcp_ddr/$BSP_BOARD_TARGET/" $RELEASE_BUILD_DIR/$BSP_DIR_NAME/board_env.xml 

cp -R $ROOT_PROJECT_PATH/linux64 $RELEASE_BUILD_DIR/$BSP_DIR_NAME/
mkdir -p $RELEASE_BUILD_DIR/$BSP_DIR_NAME/hardware/
cp -R $ROOT_PROJECT_PATH/hardware/$BSP_BOARD_TARGET $RELEASE_BUILD_DIR/$BSP_DIR_NAME/hardware/
cd $RELEASE_BUILD_DIR/$BSP_DIR_NAME/hardware/$BSP_BOARD_TARGET/
sh import_blue_bits.sh
rm $RELEASE_BUILD_DIR/$BSP_DIR_NAME/hardware/$BSP_BOARD_TARGET/*.sh
rm -fr $RELEASE_BUILD_DIR/$BSP_DIR_NAME/hardware/$BSP_BOARD_TARGET/extra_sim_files
rm -f $RELEASE_BUILD_DIR/$BSP_DIR_NAME/hardware/$BSP_BOARD_TARGET/mem_sim_model.sv
cp -R $ROOT_PROJECT_PATH/hardware/$BSP_BOARD_TARGET/run.sh $RELEASE_BUILD_DIR/$BSP_DIR_NAME/hardware/$BSP_BOARD_TARGET

#tar it up
cd $RELEASE_BUILD_DIR
tar c $BSP_DIR_NAME | gzip -9 > $RELEASE_TAR_PATH

#basic sanity checks
rm -fr $PACKAGE_TEST_DIR
mkdir $PACKAGE_TEST_DIR
cd $PACKAGE_TEST_DIR

tar xzf $RELEASE_TAR_PATH
AOCL_BOARD_PACKAGE_ROOT=$PACKAGE_TEST_DIR/$BSP_DIR_NAME aocl board-xml-test
AOCL_BOARD_PACKAGE_ROOT=$PACKAGE_TEST_DIR/$BSP_DIR_NAME aoc --list-boards