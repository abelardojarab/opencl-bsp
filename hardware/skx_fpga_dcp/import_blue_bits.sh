#!/bin/bash

[ ! -z "$1" ] && ADAPT_DEST_ROOT="$1"
[ ! -z "$2" ] && DCP_PLATFORM_REL_PATH="$2"

if [ -z "$ADAPT_DEST_ROOT" ]; then
	echo "ERROR: ADAPT_DEST_ROOT is not set.  Cannot find platform binaries for PR flow"
	exit 1
fi

[ -z "$DCP_PLATFORM_REL_PATH" ] && DCP_PLATFORM_REL_PATH="platform/dcp_1.0-skx/build"

FULL_PLATFORM_PATH=$ADAPT_DEST_ROOT/$DCP_PLATFORM_REL_PATH

echo "INFO: importing blue bits from platform path: $FULL_PLATFORM_PATH"

copy_platform_file() {
	SRC_FILE=$1
	DEST_PATH=$2
	
	if [ ! -f "$SRC_FILE" ]; then
		echo "ERROR: $SRC_FILE not found"
		exit 1
	fi
	
	cp $SRC_FILE $DEST_PATH
}

rm -fr "blue_bits"
mkdir "blue_bits"

copy_platform_file "$FULL_PLATFORM_PATH/dcp.qdb" "."
copy_platform_file "$FULL_PLATFORM_PATH/output_files/dcp.green_region.msf" "blue_bits"
copy_platform_file "$FULL_PLATFORM_PATH/output_files/dcp.sof" "blue_bits"
copy_platform_file "$FULL_PLATFORM_PATH/output_files/dcp.static.msf" "blue_bits"

