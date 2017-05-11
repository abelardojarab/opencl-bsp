#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

source $SCRIPT_DIR_PATH/bsp_common.sh

#setup arc if needed
setup_arc_for_script $@

aoc $@
