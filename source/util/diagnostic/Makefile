ECHO = @
CXX = g++ -o 
CPPFLAGS = -DOPTION3=1 -DACL_USE_DMA=1 -DACL_COMPILER_IS_MSVC=0 -Wall -Wno-unknown-pragmas -D__USE_XOPEN2K8 -Werror -DACL_HAS_STDLIB_STDIO -DACL_HOST_RUNTIME_IS_STATIC=0 -DACL_OPENCL_HOST_SYS=linux -DACL_OPENCL_HOST_BIT=64 -DACL_TARGET_SYS=linux -DACL_TARGET_BIT=64 -DLINUX -I. -I../../include -I$(ALTERAOCLSDKROOT)/host/include
CXXFLAGS = -fPIC -m64

LINKER = g++
LINKER_LIBDIRARGS = -L$(TOP_DEST_DIR)/linux64/lib -L$(ALTERAOCLSDKROOT)/host/linux64/lib -L$(AOCL_BOARD_PACKAGE_ROOT)/host/linux64/lib
LINKER_ARGS = -fPIC
LINK_LIBS = -lalteracl -lelf -lalterahalmmd -laltera_qpi_mmd   -lpthread -L%a/linux64/lib -L%b/host/linux64/lib -L/data/abrant/acds/p4/acl/regtest/designs_wip/acl_dest/linux64/lib -L/data/abrant/lib -lrt -lltdl -lCCI -lAAS -lOSAL -lpthread  -Wall -I /data/abrant/acds/p4/depot/users/ecustodi/ccie_test_2/sw/include -I/data/abrant/include -DHAVE_CONFIG_H -DTESTB -g -L/data/abrant/ -L/data/abrant/acds/p4/depot/users/ecustodi/ccie_test_2/lib  -L/usr/local/lib  -L/data/abrant/lib -lAAS -lOSAL -lxlrt -laalclp  -lASE -lfapdiag
INCORPORATE_LIBS = 
PREBUILT_OBJS = 

PERVASIVE_DEPENDENCIES = ../../include/aocl_mmd.h

MT = 

EXEFILE = diagnose 

OBJ_EXT = o
OBJS = $(patsubst %.cpp,%.$(OBJ_EXT),$(wildcard *.cpp))
OBJ_DIR?= .
OBJ_FILES = $(addprefix $(OBJ_DIR)$(PS),$(OBJS))




CUR_REL_PATH = ../..

INSTALL_DIR = $(AOCL_BOARD_PACKAGE_ROOT)/linux64/bin
TARGET_FILES = $(EXEFILE)
SUB_DIRS =

include $(CUR_REL_PATH)/Makefile.common
