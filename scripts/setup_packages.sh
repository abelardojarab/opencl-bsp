#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

#exit early and return error code if there is a problem
set -e

# use master-x OPAE for master opencl-bsp branch
#OPAE_GIT_BRANCH = 'master-x'
if [ -z "$OPAE_GIT_BRANCH" ]; then
    OPAE_GIT_BRANCH="rewind/master-x/2018-08-27"
fi
echo "setup_packages.sh OPAE_GIT_BRANCH is $OPAE_GIT_BRANCH"

#check for OPAE
if [ ! -d "$OPAE_INSTALL_PATH" ]; then
  echo "OPAE_INSTALL_PATH does not exist.  need to build"
  sh $SCRIPT_DIR_PATH/build_opae.sh
fi

#check for MMD
if [ ! -f "$AOCL_BOARD_PACKAGE_ROOT/linux64/lib/libintel_opae_mmd.so" ]; then
  echo "MMD does not exist.  need to build"
  sh $SCRIPT_DIR_PATH/build_mmd.sh
fi

echo "all packages are setup."
