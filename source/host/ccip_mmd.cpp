// Copyright(c) 2007-2016, Intel Corporation
//
// Redistribution  and  use  in source  and  binary  forms,  with  or  without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of  source code  must retain the  above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name  of Intel Corporation  nor the names of its contributors
//   may be used to  endorse or promote  products derived  from this  software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,  BUT NOT LIMITED TO,  THE
// IMPLIED WARRANTIES OF  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT  SHALL THE COPYRIGHT OWNER  OR CONTRIBUTORS BE
// LIABLE  FOR  ANY  DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY,  OR
// CONSEQUENTIAL  DAMAGES  (INCLUDING,  BUT  NOT LIMITED  TO,  PROCUREMENT  OF
// SUBSTITUTE GOODS OR SERVICES;  LOSS OF USE,  DATA, OR PROFITS;  OR BUSINESS
// INTERRUPTION)  HOWEVER CAUSED  AND ON ANY THEORY  OF LIABILITY,  WHETHER IN
// CONTRACT,  STRICT LIABILITY,  OR TORT  (INCLUDING NEGLIGENCE  OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,  EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//****************************************************************************
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include <uuid/uuid.h>
#include <fpga/enum.h>
#include <fpga/access.h>
#include <fpga/common.h>

#include "aocl_mmd.h"
#include "pkg_editor.h"

using namespace std;

#define AFU_ID "C000C966-0D82-4272-9AEF-FE5F84570612"

//for DDR through MMIO
#define MEM_WINDOW_CRTL 0xc800
#define MEM_WINDOW_MEM 0x10000
#define MEM_WINDOW_SPAN (64*1024)
#define MEM_WINDOW_SPAN_MASK ((long)(MEM_WINDOW_SPAN-1))

#ifdef SIM
//TODO: put sim specific stuff here
#endif

//for debug
#define DCP_DEBUG_MEM(...) 
//#define DCP_DEBUG_MEM(...) printf(__VA_ARGS__)
#define DEBUG_PRINT(...)
//#define DEBUG_PRINT(...) printf(__VA_ARGS__)

// Define handle values for kernel, kernel_clk (pLL), and global memory
typedef enum {
  CCIP_DFH_RANGE = 0x0000,  
  AOCL_IRQ_POLLING_BASE = 0x0100,  
  QPI_ADDR_RANGE = 0x2000,  
  DEBUG_ADDR_RANGE = 0x3000,  
  AOCL_MMD_KERNEL = 0x4000,      /* Control interface into kernel interface */
  AOCL_MMD_MEMORY = 0x100000,      /* Data interface to device memory */
  AOCL_MMD_PLL = 0xb000,         /* Interface for reconfigurable PLL */
  AOCL_MMD_PR_BASE_ID = 0xcf80,
  AOCL_MMD_VERSION_ID = 0xcfc0
} aocl_mmd_interface_t;

//macros
#define HW_UNLOCK ;
#define HW_LOCK ;

#define RESULT_INT(X) {*((int*)param_value) = X; if (param_size_ret) *param_size_ret=sizeof(int);}
#define RESULT_STR(X) do { \
    unsigned Xlen = strlen(X) + 1; \
    memcpy((void*)param_value,X,(param_value_size <= Xlen) ? param_value_size : Xlen); \
    if (param_size_ret) *param_size_ret=Xlen; \
  } while(0)

// static helper functions
static bool check_for_svm_env();

//mmd implementation
AOCL_MMD_CALL void * aocl_mmd_shared_mem_alloc( int handle, size_t size, unsigned long long *device_ptr_out )
{
	printf("aocl_mmd_shared_mem_alloc is not implemented\n");
	exit(1);
}

AOCL_MMD_CALL void aocl_mmd_shared_mem_free ( int handle, void* host_ptr, size_t size )
{
	printf("aocl_mmd_shared_mem_free is not implemented\n");
	exit(1);
}



// Reprogram the device
int AOCL_MMD_CALL aocl_mmd_reprogram(int handle, void *data, size_t data_size)
{
	printf("aocl_mmd_reprogram is not implemented\n");
	exit(1);
	return 0;
}
  
int AOCL_MMD_CALL aocl_mmd_yield(int handle)
{
  	printf("aocl_mmd_yield is not implemented\n");
	exit(1);
	return 0;
}

static bool check_for_svm_env()
{
	static bool env_checked = false;
	static bool svm_enabled = false;
	
	if(!env_checked)
	{
		if(getenv("ENABLE_DCP_OPENCL_SVM")){
			svm_enabled = true;
		}
		env_checked = true;
	}
	
	return svm_enabled;
}
  	  
int aocl_mmd_get_offline_info(
    aocl_mmd_offline_info_t requested_info_id,
    size_t param_value_size,
    void* param_value,
    size_t* param_size_ret )
{
  int mem_type_info = (int)AOCL_MMD_PHYSICAL_MEMORY;
  if(check_for_svm_env())
  	  mem_type_info = (int)AOCL_MMD_SVM_COARSE_GRAIN_BUFFER;
	
  switch(requested_info_id)
  {
    case AOCL_MMD_VERSION:              RESULT_STR("14.1"); break;
    case AOCL_MMD_NUM_BOARDS:           RESULT_INT(1); break;
    case AOCL_MMD_VENDOR_NAME:          RESULT_STR("Intel Corp"); break;
    case AOCL_MMD_BOARD_NAMES:          RESULT_STR("acl0"); break;
    case AOCL_MMD_VENDOR_ID:            RESULT_INT(0); break;
    case AOCL_MMD_USES_YIELD:           RESULT_INT(1); break;
    case AOCL_MMD_MEM_TYPES_SUPPORTED:  RESULT_INT(mem_type_info); break;
  }
  
  return 0;
}

int aocl_mmd_get_info(
    int handle,
    aocl_mmd_info_t requested_info_id,
    size_t param_value_size,
    void* param_value,
    size_t* param_size_ret )
{
  HW_LOCK;
  switch(requested_info_id)
  {
    case AOCL_MMD_BOARD_NAME:            RESULT_STR("SKX DCP FPGA OpenCL BSP"); break;
    case AOCL_MMD_NUM_KERNEL_INTERFACES: RESULT_INT(1); break;
    case AOCL_MMD_KERNEL_INTERFACES:     RESULT_INT(AOCL_MMD_KERNEL); break;
    #ifdef SIM 
    case AOCL_MMD_PLL_INTERFACES:        RESULT_INT(-1); break;
    #else
    case AOCL_MMD_PLL_INTERFACES:        RESULT_INT(-1); break;
    #endif
    case AOCL_MMD_MEMORY_INTERFACE:      RESULT_INT(AOCL_MMD_MEMORY); break;
    case AOCL_MMD_PCIE_INFO:             RESULT_STR("N/A"); break;
    case AOCL_MMD_BOARD_UNIQUE_ID:       RESULT_INT(0); break;
    case AOCL_MMD_TEMPERATURE:
      {
      	//TODO: I think FME has temperature reading.  If available, we could
      	//probobly use that
        float *r;
        int temp = 0;
        r = (float*)param_value;
        *r = (float)temp;
        if (param_size_ret)
          *param_size_ret = sizeof(float);
        break;
      }
  }
  HW_UNLOCK;
  return 0;
}

int AOCL_MMD_CALL aocl_mmd_set_interrupt_handler( int handle, aocl_mmd_interrupt_handler_fn fn, void* user_data )
{
	//this code is mostly same but with new API
	printf("aocl_mmd_set_interrupt_handler is not implemented\n");
	exit(1);
	return 0;
}

int AOCL_MMD_CALL aocl_mmd_set_status_handler( int handle, aocl_mmd_status_handler_fn fn, void* user_data )
{
	//this code is mostly same but with new API
	printf("aocl_mmd_set_status_handler is not implemented\n");
	exit(1);
	return 0;
}

// Host to device-global-memory write
int AOCL_MMD_CALL aocl_mmd_write(
    int handle,
    aocl_mmd_op_t op,
    size_t len,
    const void* src,
    int mmd_interface, size_t offset )
{
	//this code is mostly same but with new API
	printf("aocl_mmd_write is not implemented\n");
	exit(1);
	return 0;
	/*if(mmd_interface == AOCL_MMD_MEMORY)
	{
		DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_write called with AOCL_MMD_MEMORY!\n");
		DCP_DEBUG_MEM("DCP DEBUG: len=%d offset = %08x, data = %08x\n", len, (unsigned)offset,((int *)src)[0]);
		
		void * host_addr = const_cast<void *>(src);
	    long dev_addr  = offset;
	    
		long cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		pCCIPMMD->MMIOWriteFast(MEM_WINDOW_CRTL, &cur_mem_page, 8);
		DCP_DEBUG_MEM("DCP DEBUG: set page %08x\n", cur_mem_page);
		for(long i = 0; i < len/8; i++)
		{
			long mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
			if(mem_page != cur_mem_page)
			{
				cur_mem_page = mem_page;
				pCCIPMMD->MMIOWriteFast(MEM_WINDOW_CRTL, &cur_mem_page, 8);
				DCP_DEBUG_MEM("DCP DEBUG: set page %08x\n", cur_mem_page);
			}
			pCCIPMMD->MMIOWriteFast(MEM_WINDOW_MEM+(dev_addr&MEM_WINDOW_SPAN_MASK), host_addr, 8);
			DCP_DEBUG_MEM("DCP DEBUG: write data %08x %08x %016lx\n", host_addr, dev_addr, ((long *)host_addr)[0]);
			
			host_addr += 8;
			dev_addr += 8;
		}
		
		DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_write done!\n");
	}
	else
	{
	
  unsigned long int address = mmd_interface + offset; // We defined it this way
  
  HW_LOCK;

  DEBUG_PRINT("mmd write: address = %09x, offset = %08x, data = %08x\n",address, (unsigned)offset,((int *)src)[0]);

	int result = pCCIPMMD->MMIOWrite(address, src, len);
    #ifdef SIM    
  sleep(2);
  #endif
  	}
  if (op)
  {
    //assert(event_update);
    event_update(handle, event_update_user_data, op, 0);
  }
  HW_UNLOCK;

  
  return 0;*/
}

int AOCL_MMD_CALL aocl_mmd_read(
    int handle,
    aocl_mmd_op_t op,
    size_t len,
    void* dst,
    int mmd_interface, size_t offset )
{
	//this code is mostly same but with new API
	printf("aocl_mmd_read is not implemented\n");
	exit(1);
	return 0;
/*	if(mmd_interface == AOCL_MMD_MEMORY)
	{
		DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_read called with AOCL_MMD_MEMORY!\n");
		DCP_DEBUG_MEM("DCP DEBUG: len: %d offset: %08x\n", len, offset);
		
		void * host_addr = const_cast<void *>(dst);
	    long dev_addr  = offset;
	    
		long cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		pCCIPMMD->MMIOWriteFast(MEM_WINDOW_CRTL, &cur_mem_page, 8);
		DCP_DEBUG_MEM("DCP DEBUG: set page %08x\n", cur_mem_page);
		for(long i = 0; i < len/8; i++)
		{
			long mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
			if(mem_page != cur_mem_page)
			{
				cur_mem_page = mem_page;
				pCCIPMMD->MMIOWriteFast(MEM_WINDOW_CRTL, &cur_mem_page, 8);
				DCP_DEBUG_MEM("DCP DEBUG: set page %08x\n", cur_mem_page);
			}
			pCCIPMMD->MMIOReadFast(MEM_WINDOW_MEM+(dev_addr&MEM_WINDOW_SPAN_MASK), host_addr, 8);
			DCP_DEBUG_MEM("DCP DEBUG: read data %08x %08x %016lx\n", host_addr, dev_addr, ((long *)host_addr)[0]);
			
			host_addr += 8;
			dev_addr += 8;
		}
		DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_read done!\n");
	}
	else
	{
  int address = mmd_interface + offset; // We defined it this way
  HW_LOCK;

  DEBUG_PRINT("aocl_mmd_read len: %d offset: %d mmd_interface: %d   address: %d \n", len, offset, mmd_interface, address);
  #ifdef SLOW    
  sleep(2);
  #endif 
  int result = pCCIPMMD->MMIORead(address, dst, len);

  	}  
  if (op)
  {
    //assert(event_update);
    event_update(handle, event_update_user_data, op, 0);
  }

  HW_UNLOCK;
  return 0;*/
}

int AOCL_MMD_CALL aocl_mmd_copy(
    int handle,
    aocl_mmd_op_t op,
    size_t len,
    int mmd_interface, size_t src_offset, size_t dst_offset )
{
	HW_LOCK;
	printf("aocl_mmd_copy is not implemented\n");
	exit(1);
	HW_UNLOCK;
	return 0;
}

int AOCL_MMD_CALL aocl_mmd_open(const char *name)
{
	fpga_properties    filter = NULL;
	fpga_guid          guid;

	fpga_result     res = FPGA_OK;

	if (uuid_parse(AFU_ID, guid) < 0) {
		fprintf(stderr, "Error parsing guid '%s'\n", AFU_ID);
		return 0;
	}

	/* Look for AFC with AFU_ID */
	res = fpgaGetProperties(NULL, &filter);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error creating properties object\n");
		return 0;
	}
	
	res = fpgaPropertiesSetObjectType(filter, FPGA_AFC);

	res = fpgaPropertiesSetGuid(filter, guid);

	fpga_token         afc_token;
	fpga_handle        afc_handle;
	uint32_t           num_matches;
	//TODO: Add selection via BDF / device ID
	res = fpgaEnumerate(&filter, 1, &afc_token, 1, &num_matches);
	
	printf("aocl_mmd_open is not implemented\n");
	exit(1);
	return 0;
}

int AOCL_MMD_CALL  aocl_mmd_close(int handle) 
{
	printf("aocl_mmd_close is not implemented\n");
	exit(1);
	return 0;
}

