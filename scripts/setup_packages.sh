#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
. $SCRIPT_DIR_PATH/sim_common.sh

#check for AAL
if [ ! -d "$AALSDK" ]; then
  echo "AALSDK does not exist.  need to build"
  sh $SCRIPT_DIR_PATH/build_aal.sh
fi

#check for aal clock util
if [ ! -f "$ROOT_PROJECT_PATH/linux64/bin/aal_6.2.1_skx-p_user_clk.bin" ]; then
  echo "aal clock tool does not exist.  need to build"
  sh $SCRIPT_DIR_PATH/build_aal_clock_tool.sh
fi

#check for MPF
if [ ! -d "$MPF_INSTALL_PATH" ]; then
  echo "MPF does not exist.  need to build"
  sh $SCRIPT_DIR_PATH/setup_mpf.sh
fi

#check for MMD
if [ ! -f "$AOCL_BOARD_PACKAGE_ROOT/host/linux64/lib/libaltera_qpi_mmd.so" ]; then
  echo "MMD does not exist.  need to build"
  sh $SCRIPT_DIR_PATH/build_mmd.sh
fi

echo "all packages are setup."