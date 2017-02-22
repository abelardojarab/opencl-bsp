#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

ARC_RESOURCES_NEEDED="vcs,vcs-vcsmx-lic/vrtn-dev,gcc/4.8.2,acl/16.0.2,vcs,acds/16.0.2,qedition/pro,python"
SCRIPT_ARGS="$@"

#check for opencl aoc command, and get resources if needed
which aoc &> /dev/null
if [ "$?" != "0" ]; then
	echo warning: missing aoc command, using ARC
	arc shell $ARC_RESOURCES_NEEDED -- $SCRIPT_PATH $SCRIPT_ARGS
	exit $?
fi

. $SCRIPT_DIR_PATH/sim_common.sh

export OPENCL_ASE_SIM=1
$SCRIPT_DIR_PATH/setup_packages.sh
cd $ROOT_PROJECT_PATH/example_designs/mem_bandwidth
aoc device/mem_bandwidth.cl -o bin/mem_bandwidth.aocx
rm -fr bin/mem_bandwidth
aocl program acl0 bin/mem_bandwidth.aocx
make
./bin/mem_bandwidth 1
