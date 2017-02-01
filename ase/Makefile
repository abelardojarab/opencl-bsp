# #############################################################################
# Copyright (c) 2011-2016, Intel Corporation
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# * Neither the name of Intel Corporation nor the names of its contributors
# may be used to endorse or promote products derived from this software
# without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# 
# #############################################################################
# 
# Module Info:
# Language   : System{Verilog} | C/C++
# Owner      : Rahul R Sharma
#              rahul.r.sharma@intel.com
#              Intel Corporation
# 
# ASE environment build - Makefile
# 
#########################################################################
# Provides a template for compiling ASE with RTL CAFU sources in VCS
# and Questasim
# For a full experience, roll your own Makefile
#
##########################################################################

include ase_sources.mk

## ASE Version
ASE_VERSION = 5.0.2

# Enable Altera gates library
GLS_SIM = 1

# Timescale
TIMESCALE = 1ns/1ns

# ASE Source directory
ASE_SRCDIR = $(shell pwd)

#########################################################################
#                          Default options                              #
#########################################################################
## Choice of VCS or QUESTA ##
SIMULATOR?=VCS
CC=gcc

## Include directory
ifeq ($(SIMULATOR), VCS)
TOOL_DPI_INCDIR=$(VCS_HOME)
endif
ifeq ($(SIMULATOR), QUESTA)
TOOL_DPI_INCDIR=$(MTI_HOME)
endif

## C Compiler options
CC_OPT = -g -m64 -fPIC -D SIM_SIDE=1 -I $(TOOL_DPI_INCDIR)/include 

## Print information ##
 $(info SIMULATOR=$(SIMULATOR))
 $(info CC=$(CC))


#########################################################################
#                          Build Variables                              #
#########################################################################
# Variables
ASE_SHOBJ_NAME = ase_libs
ASE_SHOBJ_SO = $(ASE_SHOBJ_NAME).so

# Work directory
WORK = work

# -lrt option is required in order to use shared memory /dev/shm,
# -message queues and pthreads
ASE_LD_SWITCHES= -lrt -lpthread -lstdc++


#########################################################################
#                          VCS Build Switches                           #
#########################################################################
## VHDL compile
SNPS_VHDLAN_OPT = -nc -verbose -full64
SNPS_VHDLAN_OPT+= -work $(WORK)

## Verilog compile
SNPS_VLOGAN_OPT = -nc -V -full64 +v2k -sverilog -l vlogan.log
SNPS_VLOGAN_OPT+= +incdir+$(DUT_INCDIR) +incdir+$(ASE_INCDIR)
SNPS_VLOGAN_OPT+= +define+MMIO_RESPONSE_TIMEOUT=32768
SNPS_VLOGAN_OPT+= +librescan -work $(WORK) -override_timescale=$(TIMESCALE)
SNPS_VLOGAN_OPT+= +define+VENDOR_ALTERA +define+TOOL_QUARTUS +define+NUM_AFUS=1 +define+NLB400_MODE_0
SNPS_VLOGAN_OPT+= +lint=all,noVCDE,noNS
ifdef GLS_SIM
  SNPS_VLOGAN_OPT+= $(QUARTUS_HOME)/eda/sim_lib/altera_primitives.v
  SNPS_VLOGAN_OPT+= $(QUARTUS_HOME)/eda/sim_lib/220model.v
  SNPS_VLOGAN_OPT+= $(QUARTUS_HOME)/eda/sim_lib/sgate.v
  SNPS_VLOGAN_OPT+= $(QUARTUS_HOME)/eda/sim_lib/altera_mf.v
  SNPS_VLOGAN_OPT+= $(QUARTUS_HOME)/eda/sim_lib/stratixv_atoms.v
  SNPS_VLOGAN_OPT+= $(QUARTUS_HOME)/eda/sim_lib/synopsys/stratixv_hssi_atoms_ncrypt.v
  SNPS_VLOGAN_OPT+= $(QUARTUS_HOME)/eda/sim_lib/stratixv_hssi_atoms.v
  SNPS_VLOGAN_OPT+= $(QUARTUS_HOME)/eda/sim_lib/stratixv_pcie_hip_atoms.v
  SNPS_VLOGAN_OPT+= $(QUARTUS_HOME)/eda/sim_lib/altera_lnsim.sv
endif

## VCS elaboration
SNPS_VCS_OPT = -nc -V +vcs+lic+wait -full64 -debug_all -Mupdate -lca
SNPS_VCS_OPT+= -l vcs_elab.log +vhdllib+$(WORK) -Mlib=$(WORK) 
SNPS_VCS_OPT+= -override_timescale=$(TIMESCALE) -o $(WORK)/ase_simv

## Simulation options
VCS_SIM_OPT = -l run.log -ucli -do $(ASE_SRCDIR)/vcs_run.tcl

#########################################################################
#                         Questa Build Switches                         #
#########################################################################
## VHDL compile
MENT_VCOM_OPT = -nologo -work $(WORK)

## VLOG compile
MENT_VLOG_OPT = -64 -novopt -nologo +librescan -work $(WORK) 
MENT_VLOG_OPT+= +incdir+$(DUT_INCDIR) +incdir+$(ASE_INCDIR) 
MENT_VLOG_OPT+= -sv  -timescale $(TIMESCALE) -l vlog.log

## VSIM elaboration, and run options
MENT_VSIM_OPT = -64 -c -novopt -l run.log
MENT_VSIM_OPT+= -sv_lib $(WORK)/$(ASE_SHOBJ_NAME) -do vsim_run.tcl


#########################################################################
#                            Build Targets                              #
#########################################################################
# Default
all: clean check build

# Check
check: header
ifneq ($(CC), gcc)
	@echo "#                                                          #"
	@echo "# CC=$(CC) not supported                                   #"
	@echo "# Run 'make help' for more information                     #"
	@echo "#                                                          #"
	@echo "############################################################"
	exit 1
endif
ifneq ($(SIMULATOR), VCS)
  ifneq ($(SIMULATOR), QUESTA)
	@echo "#                                                          #"
	@echo "# SIMULATOR=$(SIMULATOR) not supported                     #"
	@echo "# Run 'make help' for more information                     #"
	@echo "#                                                          #"
	@echo "############################################################"
	exit 1
  endif
endif


# Print version number
header:
	@echo "############################################################"
	@echo "#                                                          #"
	@echo "#       Xeon(R) + FPGA Accelerator Abstraction Layer       #"
	@echo "#             AFU Simulation Environment (ASE)             #"
	@echo "#                                                          #"
	@echo "############################################################"


# Help information
help: header
	@echo "#                                                          #"
	@echo "#  COMMAND       |   DESCRIPTION                           #"
	@echo "# -------------------------------------------------------- #"
	@echo "# make           | Build the HW Model using RTL supplied   #"
	@echo "#                |                                         #"
	@echo "# make sim       | Run simulator                           #"
	@echo "#                | - ASE can be run in one of 4 modes set  #"
	@echo "#                |   in ase.cfg                            #"
	@echo "#                | - A regression mode can be enabled by   #"
	@echo "#                |   writing ASE_MODE = 4 in ase.cfg and   #"
	@echo "#                |   supplying an ase_regress.sh script    #"
	@echo "#                |                                         #"
	@echo "# make wave      | Open the waveform (if created)          #"
	@echo "#                | To be run after simulation completes    #"
	@echo "#                |                                         #"
	@echo "# make clean     | Clean simulation files                  #"
	@echo "#                |                                         #"
	@echo "# make distclean | Clean ASE sub-distribution              #"
	@echo "#                                                          #"
	@echo "############################################################"


## Build ASE Software objects and shared library ##
sw_build:
	make header
	mkdir -p $(WORK)
	cd $(WORK) ; $(CC) $(CC_OPT) -c $(ASESW_FILE_LIST) || exit 1 ; cd -
	cd $(WORK) ; $(CC) -g -shared -o $(ASE_SHOBJ_SO) `ls *.o` $(ASE_LD_SWITCHES) ; cd -
	nm $(WORK)/$(ASE_SHOBJ_SO) > $(WORK)/$(ASE_SHOBJ_NAME).nm

## VCS build template ##
vcs_build:
	@echo "############################################################"
	@echo "#                                                          #"
	@echo "#                VCS-GCC build initiated                   #"
	@echo "#                                                          #"
	@echo "############################################################"
	make sw_build
	vlogan $(SNPS_VLOGAN_OPT) $(ASEHW_FILE_LIST)
ifdef DUT_VHD_SRC_LIST
	vhdlan $(SNPS_VHDLAN_OPT) -f $(DUT_VHD_SRC_LIST)
endif
ifdef DUT_VLOG_SRC_LIST
	vlogan $(SNPS_VLOGAN_OPT) -f $(DUT_VLOG_SRC_LIST)
endif
ifeq ($(CC), gcc)
	vcs $(SNPS_VCS_OPT) $(ASE_TOP) $(WORK)/$(ASE_SHOBJ_SO) $(ASE_LD_SWITCHES)
endif


## Questasim template ##
questa_build:
	@echo "############################################################"
	@echo "#                                                          #"
	@echo "#              QuestaSim-GCC build initiated               #"
	@echo "#                                                          #"
	@echo "############################################################"
	vlib $(WORK)
	vmap work $(WORK)
	make sw_build
ifdef DUT_VHD_SRC_LIST
	vcom $(MENT_VCOM_OPT) -f $(DUT_VHD_SRC_LIST)
endif
ifdef DUT_VLOG_SRC_LIST
	vlog $(MENT_VLOG_OPT) -f $(DUT_VLOG_SRC_LIST)
endif
	vlog $(MENT_VLOG_OPT) $(ASEHW_FILE_LIST)


## Build Simulator objects ## 
build:
ifeq ($(SIMULATOR), VCS)
	make vcs_build
else
  ifeq ($(SIMULATOR), QUESTA)
	make questa_build
  else
	@echo "############################################################"
	@echo "#         SIMULATOR=$(SIMULATOR) not supported             #"
	@echo "############################################################"
  endif
endif

## Run ASE Simulator ##
sim: check
ifeq ($(SIMULATOR), VCS)
	cd ./$(WORK)/; ./ase_simv $(VCS_SIM_OPT) +CONFIG=$(ASE_SRCDIR)/ase.cfg +SCRIPT=$(ASE_SRCDIR)/ase_regress.sh ; cd -
else
  ifeq ($(SIMULATOR), QUESTA)
	vsim $(MENT_VSIM_OPT) $(ASE_TOP) 
  else
	@echo "############################################################"
	@echo "#         SIMULATOR=$(SIMULATOR) not supported             #"
	@echo "############################################################"
  endif
endif

# Open Wave file
wave: check
ifeq ($(SIMULATOR), VCS)
	dve -vpd `find . -name inter.vpd` || dve -vpd `find . -name inter.vpd` -full64
else
  ifeq ($(SIMULATOR), QUESTA)
	vsim -view vsim.wlf
  endif
endif


#########################################################################
#                            Clean all                                  #
#########################################################################
clean: header
	rm -rf work/ *.log *.tsv AN.DB/ || echo "make: Didn't clean up work"
	rm -rf csrc/ vc_hdrs.h .vlogansetup.* *.vpd 
	rm -rf transcript modelsim.ini vsim.wlf ucli.key vsim_stacktrace.vstf
	rm -rf profile* simprofile* urgReport/
	rm -rf .ase_* *.o ase_seed.txt warnings.txt

distclean: header clean
	./distclean.sh


