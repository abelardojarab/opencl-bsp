# (C) 2017 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other
# software and tools, and its AMPP partner logic functions, and any output
# files any of the foregoing (including device programming or simulation
# files), and any associated documentation or information are expressly subject
# to the terms and conditions of the Intel Program License Subscription
# Agreement, Intel MegaCore Function License Agreement, or other applicable
# license agreement, including, without limitation, that your use is for the
# sole purpose of programming logic devices manufactured by Intel and sold by
# Intel or its authorized distributors.  Please refer to the applicable
# agreement for further details.


cmake_minimum_required(VERSION 2.8.12)
project(a10_dcp)

#set(AOCL_BOARD_PACKAGE_ROOT $ENV{AOCL_BOARD_PACKAGE_ROOT})
set(OPAE_INSTALL_PATH $ENV{OPAE_INSTALL_PATH})
set(ALTERAOCLSDKROOT $ENV{ALTERAOCLSDKROOT})


link_directories("${ALTERAOCLSDKROOT}/host/linux64/lib")
link_directories("${CMAKE_SOURCE_DIR}/../linux64/lib")
link_directories("${CMAKE_SOURCE_DIR}/host/lib")
link_directories("${OPAE_INSTALL_PATH}/lib")

option(OPENCL_ASE_SIM "Build for ASE simulation" OFF)
if(OPENCL_ASE_SIM)
   set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DSIM")
endif()

include_directories(
   ${OPAE_INSTALL_PATH}/include
   ${CMAKE_CURRENT_SOURCE_DIR}
   ${CMAKE_SOURCE_DIR}/include
   ${ALTERAOCLSDKROOT}/host/include
)

# TODO: use find_package to locate required packages
# instead of relying on environment variables
#find_package(opae REQUIRED)

set (CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11") 

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3") 
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3") 

add_subdirectory(host)
add_subdirectory(util)
add_subdirectory(safe_string)
