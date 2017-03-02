#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

ARC_RESOURCES_NEEDED="vcs,vcs-vcsmx-lic/vrtn-dev,gcc/4.8.2,acl/16.0.2,vcs,acds/16.0.2,qedition/pro,python"

export OPENCL_ASE_SIM=1
arc shell $ARC_RESOURCES_NEEDED -- $SCRIPT_DIR_PATH/setup_packages.sh
arc shell $ARC_RESOURCES_NEEDED -- $SCRIPT_DIR_PATH/run_full_opencl_sim_test.sh
