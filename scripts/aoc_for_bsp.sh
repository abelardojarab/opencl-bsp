#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

source $SCRIPT_DIR_PATH/bsp_common.sh

ARC_RESOURCES_NEEDED="$ACDS_ARC_RESOURCES,adapt"
AOC_ARGS="$@"

#check for opencl aoc command, and get resources if needed
which aoc &> /dev/null
if [ "$?" != "0" ]; then
	echo warning: missing aoc command, using ARC
	arc shell $ARC_RESOURCES_NEEDED -- $SCRIPT_PATH $AOC_ARGS
	exit $?
fi

aoc $AOC_ARGS