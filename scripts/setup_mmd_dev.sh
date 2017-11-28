#!/bin/bash

ORG_SCRIPT_PATH=${BASH_SOURCE[0]}
SCRIPT_PATH=$(readlink -f $ORG_SCRIPT_PATH)
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
source ${SCRIPT_DIR_PATH}/bsp_common.sh

if [ "$ARC_SW_CONFIGURED" !=  "1" ]; then
	export ARC_SW_CONFIGURED=1
	arc shell ${ACDS_ARC_RESOURCES},${SW_BUILD_ARC_RESOURCES} -- ${ORG_SCRIPT_PATH} $@
	unset ARC_SW_CONFIGURED
fi

if [ "$ARC_SW_CONFIGURED" == 1 ]; then
	if [ ! -d "${OPAE_BUILD_PATH}" ]; then
		OPAE_USE_GIT_ARCHIVE='0' ${SCRIPT_DIR_PATH}/build_opae.sh
		OPAE_USE_GIT_ARCHIVE='0' ${SCRIPT_DIR_PATH}/build_mmd.sh
	else
		pushd $PWD
		cd $OPAE_SRC_PATH && git pull
		cd $OPAE_BUILD_PATH && make install
		popd
	fi
else
	exec arc shell $ACDS_ARC_RESOURCES,$SW_BUILD_ARC_RESOURCES -- $@
fi
