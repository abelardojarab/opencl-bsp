#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

cd $ROOT_PROJECT_PATH/packages/aal_clock_utility
make prefix=$AALSDK
cp aal_6.2.1_skx-p_user_clk.bin $ROOT_PROJECT_PATH/linux64/bin/
