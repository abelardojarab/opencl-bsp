#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

. $SCRIPT_DIR_PATH/bsp_common.sh

ARC_RESOURCES_NEEDED="vcs,vcs-vcsmx-lic/vrtn-dev,gcc/4.8.2,$ACDS_ARC_RESOURCES,python"
SCRIPT_ARGS="$@"

#check for opencl aoc command, and get resources if needed
which aoc &> /dev/null
if [ "$?" != "0" ]; then
	echo warning: missing aoc command, using ARC
	arc shell $ARC_RESOURCES_NEEDED -- $SCRIPT_PATH $SCRIPT_ARGS
	exit $?
fi

export OPENCL_ASE_SIM=1
$SCRIPT_DIR_PATH/setup_packages.sh
cd $ROOT_PROJECT_PATH/example_designs/vector_add_int
rm -fr bin/vector_add_int
aoc vector_add_int.cl --board skx_fpga_dcp_ddr -o bin/vector_add_int.aocx
#aoc vector_add_int.cl --board skx_fpga_dcp_svm -o bin/vector_add_int.aocx
rm -fr vector_add_int_comp
mv bin/vector_add_int vector_add_int_comp
aocl program acl0 bin/vector_add_int.aocx
make
cp ./bin/vector_add_int .
cp bin/vector_add_int.aocx .
./vector_add_int 16
#ENABLE_DCP_OPENCL_SVM=1 ./bin/vector_add_int 16
