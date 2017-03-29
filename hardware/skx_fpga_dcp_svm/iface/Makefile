#############################################################
#
# IPUTF 
#  IP_CORE Template Makefile
#
# Owner: jyeap
#
# DO NOT COPY THIS MAKEFILE.
# Generate your very own Makefile with this command:
#   make -f $ACDS_SRC_ROOT/bcommon/ip/build_core.mk create-makefile
#
#############################################################

#############################################################
# Customize your IP core here


#############################################################

#############################################################
# Update this list by typing 'make update-makefile'
SOURCE_FILES := \
	altera_avalon_mm_cci_bridge.v \
	cci_read_granter.v \
	cci_write_granter.v \
	cci_requester.v \
	parallel_match.v \
	altera_avalon_mm_cci_bridge_hw.tcl
#############################################################

ifeq ($(ACDS_SRC_ROOT),)
$(error ACDS_SRC_ROOT not set)
endif

BUILD_CORE_MAKEFILE := $(ACDS_SRC_ROOT)/bcommon/ip/build_core.mk
ifeq ($(wildcard $(BUILD_CORE_MAKEFILE)),)
$(error $(ACDS_SRC_ROOT)/bcommon/ip not synced)
endif

# Include this build_core.mk makefile and you're done
include $(BUILD_CORE_MAKEFILE)

# type 'make help' for all your documentation needs

