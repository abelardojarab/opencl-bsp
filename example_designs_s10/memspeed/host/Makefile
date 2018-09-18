# Most logic is in regtest/util/Makefile.host.
# Setting exe-specific variables here.
# Assuming source files are in 'src' sub-dir, include files are
# in 'inc' sub-dir.

TARGET = memspeed

ifeq ($(ACL_OPENCL_HOST_SYS),arm)
SRCS = main.arm.cpp
else
SRCS = main.cpp
endif

USES_ACL_HOST_UTILS = 1

# can also set
#   PLATFORM = ACL|NVIDIA (default ACL)
#   DEBUG    = 0|1 (default 0)
#   LIBS
#   CPPFLAGS
#   LINKFLAGS


# Top-level regtest dir.
REG_LOCAL_ROOT_DIR_PATH ?= ../../../../..
include $(REG_LOCAL_ROOT_DIR_PATH)/hld/opencl/util/Makefile.host
