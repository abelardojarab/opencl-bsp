#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/bsp_common.sh

export OPENCL_ASE_SIM=0

if [ ! $MINICLOUD ]; then 
	setup_arc_for_script
fi

bash
