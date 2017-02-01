#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/sim_common.sh

cd $ROOT_PROJECT_PATH/source
make clean
make

#need to rebuild mmd for sim
cd $ROOT_PROJECT_PATH/source/host
make clean
make -f Makefile.sim