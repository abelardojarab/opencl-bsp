#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

ARC_RESOURCES_NEEDED="acl/16.0.2,acds/16.0.2,qedition/pro,adapt"
AOC_ARGS="$@"

#check for opencl aoc command, and get resources if needed
which aoc &> /dev/null
if [ "$?" != "0" ]; then
	echo warning: missing aoc command, using ARC
	arc shell $ARC_RESOURCES_NEEDED -- $SCRIPT_PATH $AOC_ARGS
	exit $?
fi

source $SCRIPT_DIR_PATH/bsp_common.sh
aoc $AOC_ARGS