#---------------------------#

ECHO = @
CXX = g++ -o 

CPPFLAGS = -DKERNEL_64BIT -Wall -Wno-unknown-pragmas  -fPIC -fpermissive -DLINUX  -D__USE_XOPEN2K8 -DACL_VERSION=\"v14.1\" -I. -I../../include -I../include -I$(ALTERAOCLSDKROOT)/host/include/CL -I$(FPGA_API_PATH)/include
#-I$(MPF_INSTALL_PATH)/sw/include
CFLAGS = -fPIC -m64 
CXXFLAGS = -fPIC -m64 -std=c++11

ifeq (1,${OPENCL_ASE_SIM})
	CFLAGS += -g
	CXXFLAGS += -g
	CPPFLAGS += -DSIM
endif

LINKER = g++
LINKER_LIBDIRARGS = -Llib -L$(ALTERAOCLSDKROOT)/host/linux64/lib
LINKER_ARGS = -lrt -fPIC
INCORPORATE_LIBS = 
PREBUILT_OBJS = 
LINK_LIBS =  -lelf

DLLFILE = lib$(MMD_LIB_NAME).so
DLLLIBFILE = 

PERVASIVE_DEPENDENCIES =  $(AOCL_BOARD_PACKAGE_ROOT)/source/include/aocl_mmd.h 

OBJ_EXT = o
OBJS = $(patsubst %.c,%.$(OBJ_EXT),$(wildcard *.c)) \
       $(patsubst %.cpp,%.$(OBJ_EXT),$(wildcard *.cpp))
OBJ_DIR?= .
OBJ_FILES = $(addprefix $(OBJ_DIR)$(PS),$(OBJS))



CUR_REL_PATH = ..

INSTALL_DIR = $(TOP_DEST_DIR)$(PS)linux64$(PS)lib
TARGET_FILES = $(DLLFILE)
SPECIAL_INSTALL_FILE = 
SUB_DIRS =

include $(CUR_REL_PATH)/Makefile.common
