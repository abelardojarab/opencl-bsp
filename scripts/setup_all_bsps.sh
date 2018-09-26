#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

#find all the BSP options that exist in /hardware/ and build each one
BSP_HW_DIR="$SCRIPT_DIR_PATH/../hardware"

cd $SCRIPT_DIR_PATH/../

for bsp_folder in "$BSP_HW_DIR"/*
do
    bsp_folder="$(basename $bsp_folder)"
    echo "Setting up this BSP: $bsp_folder"
    export DCP_BSP_TARGET=$bsp_folder
    source $SCRIPT_DIR_PATH/bsp_common.sh
    python $SCRIPT_DIR_PATH/setup_bsp.py -v
done

echo "All BSPs in hardware/ have been setup. Goodbye!"
