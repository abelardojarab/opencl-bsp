Introduction
This package is the BSP for the DCP accelerator card.  Please see the user guide
for more detailed information.

1.  HW Requirements
	Intel Xeon processor
	64 gigabytes (GB) of RAM(large designs may require more)
	A PCI Express x8 Slot
	25 GB of hard drive space
	CentOS 7.3 with the default Linux kernel 3.10

2.  Software for FPGA/OpenCL compilation:
  dcp_s10 | Statix 10 
	Quartus Prime Pro Edition 18.0.1 build 261
	Intel FPGA SDK for OpenCL Pro Edition 18.0.1 build 261
  
  dcp_a10 | Arria 10
  Patched version of Quartus Prime Pro contains bug-fixes for Arria 10 Partial Reconfiguration
	Quartus Prime Pro Version 17.1.1 Build 273 12/19/2017 Patches 1.36,1.38 SJ Pro Edition
	Intel FPGA SDK for OpenCL Pro Edition 17.1.1 build 273

3.  Software for OpenCL runtime
	system packages
		sudo yum -y install cmake autoconf automake libxml2 libxml2-devel json-c-devel boost ncurses ncurses-devel ncurses-libs boost-devel libuuid-devel
		sudo yum -y install epel-release
		sudo yum -y install dkms
	OPAE driver
		opae-intel-fpga-drv-0.3.0.x86_64.rpm
	OPAE software library
		opae-src-0.3.0.tar.gz
	Intel FPGA Runtime Environment for OpenCL Linux x86-64 RPM
		aocl-pro-rte-18.0-189.x86_64.rpm

4.  Note about initializing DCP for OpenCL:
	must do "aocl program acl0 kernel.aocx" first
		OpenCL runtime must be able to find BSP in FPGA or it will not run
		"aocl program" has a special flow to force load aocx binary when there is a non-OpenCL green bit stream loaded
		OpenCL programming/operation will work normally after this

5.  Troubleshooting
	make sure aocl diagnose works!
		if you see something like this "Error initializing DMA: 1"
		that means permissions for DMA buffers are not setup correctly
		run the bsp_install_location/OpenCL_bsp_dcp/linux64/libexec/setup_permissions.sh script
	
6.  Quick start:

a.  Setting up BSP for AOCX compilation
	cd /path/to/put/bsp/
	tar xzf dcp_OpenCL_bsp_*.tar.gz
	export AOCL_BOARD_PACKAGE_ROOT=/path/to/put/bsp/dcp_OpenCL_bsp
	aoc -list-boards
	#make sure you see at least 1 DCP board in the list
	#to use arc to compile, get these resources
  dcp_s10 | Stratix 10
	arc shell acl/18.0.1/261,acds/18.0/189,qedition/pro,adapt/18.0.1/261,python
  
  dcp_a10 | Arria 10
	arc shell acl/17.1.1,acds/swip_apps/avl_vm/acds_patched/17.1.1/acds,qedition/pro,adapt/18.1,python

	aoc vector_add.cl
	#you can also use '--board bsp_board_name' to specify a specific board variant

b.  Running OpenCL host applications  tions with DCP and OPAE software
#refer to DCP Quick Start Guide for flashing blue bits and make sure nlb0 test works

##Please make sure that the board has been flashed with the BBS.  Driver won't work without it.

#Here are specific instructions on getting runtime software running with OpenCL on DCP
#Some of these instructions are specific to OpenCL
#install needed system packages
sudo yum -y install cmake autoconf automake libxml2 libxml2-devel json-c-devel boost ncurses ncurses-devel ncurses-libs boost-devel libuuid-devel
sudo yum -y install epel-release
sudo yum -y install dkms
sudo rpm -i $DCP_LOC/sw/opae-intel-fpga-drv-0.3.0.x86_64.rpm

#setup opae
cd sw_install_location
tar xzf $DCP_LOC/sw/opae-src-0.3.0-*.tar.gz
export OPAE_LOC=`pwd`/opae-0.3.0
mkdir build && cd build
cmake .. -DINTEL_FPGA_API_VER_MAJOR=0 -DINTEL_FPGA_API_VER_MINOR=3 -DINTEL_FPGA_API_VER_REV=0 -DBUILD_ASE=ON
make -j4

#setup permissions.  run this shell script.  read shell script for details on
#permissions settings
bsp_install_location/OpenCL_bsp_dcp/linux64/libexec/setup_permissions.sh

#setup OpenCL
sudo rpm -i /path_to_OpenCL_rte_rpm/aocl-pro-rte-17.1.1-273.x86_64.rpm
mkdir bsp_install_location
tar xzf /path_to_bsp_package/dcp_OpenCL_bsp_*.tar.gz

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPAE_LOC/build/lib
export AOCL_BOARD_PACKAGE_ROOT=bsp_install_location/dcp_OpenCL_bsp
export OPAE_INSTALL_PATH=$OPAE_LOC/build/
source /opt/altera/aocl-rte/init_OpenCL.sh

#run first OpenCL programming and diagnose
aocl program acl0 hello_world.aocx
aocl diagnose
aocl diagnose acl0

#download vector add from altera.com and run it
tar xzf path_to_download/exm_OpenCL_vector_add_x64_linux.tgz
cp path_to_aocx_file/vector_add.aocx /vector_add/bin
cd vector_add
make
cd bin
./host