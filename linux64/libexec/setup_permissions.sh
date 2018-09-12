#!/bin/bash

# (C) 2018 Intel Corporation. All rights reserved.
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

old_errexit="$(shopt -po errexit)"
set -e

echo "\
This script handles device permissions and huge page table setup.

Please refer to DCP Quick Start User Guide for OPAE driver and SW installation
instructions.
"

#setup memlock.conf
if [ ! -e /etc/security/limits.d/99-opae_memlock.conf ]; then
	sudo bash -c 'echo "*                hard    memlock         unlimited" >> /etc/security/limits.d/99-opae_memlock.conf'
	sudo bash -c 'echo "*                soft    memlock         unlimited" >> /etc/security/limits.d/99-opae_memlock.conf'
	echo "updated '/etc/security/limits.d/99-opae_memlock.conf'.  reboot required."
else
	echo "/etc/security/limits.d/99-opae_memlock.conf is already setup."
fi


echo "setup huge pages.  must be done after every reboot"
echo 'sudo bash -c "echo 20 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages"'
sudo bash -c "echo 20 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages"

echo
echo "setup permissions for device.  must be done after every reboot."  
echo "sudo chmod 666 /dev/intel-fpga-port.*"
sudo chmod 666 /dev/intel-fpga-port.*
echo "sudo chmod 666 /sys/class/fpga/intel-fpga-dev.*/intel-fpga-port.*/userclk_freqcmd"
sudo chmod 666 /sys/class/fpga/intel-fpga-dev.*/intel-fpga-port.*/userclk_freqcmd
echo "sudo chmod 666 /sys/class/fpga/intel-fpga-dev.*/intel-fpga-port.*/userclk_freqcntrcmd"
sudo chmod 666 /sys/class/fpga/intel-fpga-dev.*/intel-fpga-port.*/userclk_freqcntrcmd
echo "sudo chmod 666 /sys/class/fpga/intel-fpga-dev.*/intel-fpga-port.*/errors/clear"
sudo chmod 666 /sys/class/fpga/intel-fpga-dev.*/intel-fpga-port.*/errors/clear
echo "sudo chmod 666 /dev/intel-fpga-fme.*"
sudo chmod 666 /dev/intel-fpga-fme.*

eval "$old_errexit"
