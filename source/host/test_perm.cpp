/* (C) 1992-2017 Intel Corporation.                             */
/* Intel, the Intel logo, Intel, MegaCore, NIOS II, Quartus and TalkBack words     */
/* and logos are trademarks of Intel Corporation or its subsidiaries in the U.S.   */
/* and/or other countries. Other marks and brands may be claimed as the property   */
/* of others. See Trademarks on intel.com for full list of Intel trademarks or     */
/* the Trademarks & Brands Names Database (if Intel) or See www.Intel.com/legal (if Altera)  */
/* Your use of Intel Corporation's design tools, logic functions and other         */
/* software and tools, and its AMPP partner logic functions, and any output        */
/* files any of the foregoing (including device programming or simulation          */
/* files), and any associated documentation or information are expressly subject   */
/* to the terms and conditions of the Altera Program License Subscription          */
/* Agreement, Intel MegaCore Function License Agreement, or other applicable       */
/* license agreement, including, without limitation, that your use is for the      */
/* sole purpose of programming logic devices manufactured by Intel and sold by     */
/* Intel or its authorized distributors.  Please refer to the applicable           */
/* agreement for further details.                                                  */

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>

#include <glob.h>
#include <stdio.h>

#include "test_perm.h"

static const char *FPGA_PORT_DEV = "/dev/intel-fpga-port.*";
static const char *FPGA_FME_PR_DEV_LIST[] = {
		"/sys/class/fpga/intel-fpga-dev.*/intel-fpga-port.*/userclk_freqcmd",
		"/sys/class/fpga/intel-fpga-dev.*/intel-fpga-port.*/userclk_freqcntrcmd",
		"/sys/class/fpga/intel-fpga-dev.*/intel-fpga-port.*/errors/clear",
		"/dev/intel-fpga-fme.*"
};

static const char *MEMLOCK_CONF_PATH = "/etc/security/limits.d/99-opae_memlock.conf";

static long get_num_pages_setting()
{
	#define SYSFS_2MB_HUGE_PAGES "/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages"
	const int buf_size = 16;
	char buf[buf_size];
	
	int res = open(SYSFS_2MB_HUGE_PAGES, O_RDONLY);
	if (-1 == res) 
	{
		return -1;
	} 
	else
	{
		size_t c = read(res, buf, buf_size-1);
		buf[c] = 0;
		long num_pages = atol(buf);
		close(res);
		return num_pages;
	}
}

static bool test_exists(const char *file)
{
	glob_t glob_obj;
	bool result = false;
	glob(file, GLOB_TILDE, NULL, &glob_obj);
	
	result = (glob_obj.gl_pathc > 0);
	
   globfree(&glob_obj);
	
	return result;
}

static bool test_perm(const char *file)
{
	int res = open(file, O_RDWR);
	if (-1 == res) 
	{
		return false;
	} 
	else 
	{
		close(res);
		return true;
	}
}

static bool verbose_test_perm(const char *file)
{
	bool result = test_perm(file);
	if(!result)
		printf("ERROR: R/W permissions missing on %s\n", file);
	
	return result;
}

static bool verbose_test_perm_glob(const char *file)
{
	glob_t glob_obj;
	bool result = true;
	glob(file, GLOB_TILDE, NULL, &glob_obj);
	
	for(unsigned int i = 0; i < glob_obj.gl_pathc; i++)
		result &= verbose_test_perm(glob_obj.gl_pathv[i]);
	
	result &= (glob_obj.gl_pathc > 0);
	
   globfree(&glob_obj);
	
	return result;
}

bool ccip_mmd_check_huge_pages()
{
#ifdef SIM
	return true;
#else
	long num_pages = 0;
	num_pages = get_num_pages_setting();
	
	if(num_pages > 0)
	{
		return true;
	}
	else
	{
		printf("ERROR: huge pages are not enabled\n");
		return false;
	}
	//printf("get_num_pages_setting() = %d\n", get_num_pages_setting());
#endif
}

bool ccip_mmd_check_limit_conf()
{
#ifdef SIM
	return true;
#else
	bool result = test_exists(MEMLOCK_CONF_PATH);
	if(!result)
	{
		printf("WARNING: %s not found.\n", MEMLOCK_CONF_PATH);
		printf("WARNING: This may cause DMA initialization issues.\n");
	}
	
	return result;
#endif
}

static bool check_device_file(const char *dev_file)
{
	bool result = test_exists(dev_file);
	if(!result)
	{
		printf("ERROR: Device file not found - %s\n", dev_file);
		printf("\tCheck device driver and make sure the board is flashed.\n");
		return result;
	}
	
	result &= verbose_test_perm_glob(dev_file);
	
	return result;
}

bool ccip_mmd_check_afu_driver()
{
#ifdef SIM
	return true;
#else
	return check_device_file(FPGA_PORT_DEV);
#endif
}

bool ccip_mmd_dma_setup_check()
{
	bool result = true;
	result &= ccip_mmd_check_afu_driver();
	result &= ccip_mmd_check_huge_pages();
	result &= ccip_mmd_check_limit_conf();
	return result;
}

bool ccip_mmd_check_fme_driver_for_pr()
{
#ifdef SIM
	return true;
#else
	size_t num_dev = sizeof(FPGA_FME_PR_DEV_LIST)/sizeof(FPGA_FME_PR_DEV_LIST[0]);
	
	for(size_t i = 0; i < num_dev; i++)
	{
		bool result = check_device_file(FPGA_FME_PR_DEV_LIST[i]);
		if(!result)
			return false;
	}
	return true;
#endif
}
