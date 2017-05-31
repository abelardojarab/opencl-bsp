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
#include <stdint.h>
#include <unistd.h>

#include "aocl_mmd.h"
#include "ccip_mmd_device.h"

// TODO: create map or some other data structure that supports multiple devices
// and replace all uses of ccip_dev_global with appropriate lookup function
CcipDevice *ccip_dev_global;

// static helper functions
static bool check_for_svm_env();

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

int AOCL_MMD_CALL aocl_mmd_reprogram(int handle, void *data, size_t data_size)
{
	printf("aocl_mmd_reprogram is not implemented\n");
	exit(1);
	return 0;
}

int AOCL_MMD_CALL aocl_mmd_yield(int handle)
{
	uint32_t irqval = 0;
	DEBUG_PRINT("* Called: aocl_mmd_yield\n");
	YIELD_DELAY();

	ccip_dev_global->read_block(NULL, AOCL_IRQ_POLLING_BASE, &irqval, 0, 4);
	DEBUG_PRINT("irqval: %u\n", irqval);
	if(irqval) {
		ccip_dev_global->yield();
	}

	return 0;
}

static bool check_for_svm_env()
{
	//SVM not yet supported so no reason to check right now
#if 1
	return false;
#else
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
#endif
}


// Macros used for acol_mmd_get_offline_info and aocl_mmd_get_info
#define RESULT_INT(X) {*((int*)param_value) = X; if (param_size_ret) *param_size_ret=sizeof(int);}
#define RESULT_STR(X) do { \
	unsigned Xlen = strlen(X) + 1; \
	memcpy((void*)param_value,X,(param_value_size <= Xlen) ? param_value_size : Xlen); \
	if (param_size_ret) *param_size_ret=Xlen; \
} while(0)


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
	DEBUG_PRINT("called aocl_mmd_get_info\n");
	switch(requested_info_id)
	{
		case AOCL_MMD_BOARD_NAME:            RESULT_STR("SKX DCP FPGA OpenCL BSP"); break;
		case AOCL_MMD_NUM_KERNEL_INTERFACES: RESULT_INT(1); break;
		case AOCL_MMD_KERNEL_INTERFACES:
						     RESULT_INT(AOCL_MMD_KERNEL); break;
#ifdef SIM
		case AOCL_MMD_PLL_INTERFACES:        RESULT_INT(-1); break;
#else
		case AOCL_MMD_PLL_INTERFACES:        RESULT_INT(-1); break;
#endif
		case AOCL_MMD_MEMORY_INTERFACE:
						     RESULT_INT(AOCL_MMD_MEMORY); break;
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
	return 0;
}

#undef RESULT_INT
#undef RESULT_STR

int AOCL_MMD_CALL aocl_mmd_set_interrupt_handler( int handle, aocl_mmd_interrupt_handler_fn fn, void* user_data )
{
	ccip_dev_global->set_kernel_interrupt(fn, user_data);
	return 0;
}

int AOCL_MMD_CALL aocl_mmd_set_status_handler( int handle, aocl_mmd_status_handler_fn fn, void* user_data )
{
	ccip_dev_global->set_status_handler(fn, user_data);
	return 0;
}

// Host to device-global-memory write
int AOCL_MMD_CALL aocl_mmd_write(
		int handle,
		aocl_mmd_op_t op,
		size_t len,
		const void* src,
		int mmd_interface,
		size_t offset)
{
	DCP_DEBUG_MEM("\n- aocl_mmd_write: %d\t %p\t %lu\t %p\t %d\t %lu\n",handle, op, len, src, mmd_interface, offset);
	return ccip_dev_global->write_block(op, mmd_interface, src, offset, len);

}

int AOCL_MMD_CALL aocl_mmd_read(
		int handle,
		aocl_mmd_op_t op,
		size_t len,
		void* dst,
		int mmd_interface,
		size_t offset)
{
	DCP_DEBUG_MEM("\n+ aocl_mmd_read: %d\t %p\t %lu\t %p\t %d\t %lu\n",handle, op, len, dst, mmd_interface, offset);
	return ccip_dev_global->read_block(op, mmd_interface, dst, offset, len);
}

int AOCL_MMD_CALL aocl_mmd_copy(
		int handle,
		aocl_mmd_op_t op,
		size_t len,
		int mmd_interface, size_t src_offset, size_t dst_offset )
{
	printf("aocl_mmd_copy is not implemented\n");
	exit(1);
	return 0;
}

int AOCL_MMD_CALL aocl_mmd_open(const char *name)
{
	DEBUG_PRINT("Opening device: %s\n", name);

	int unique_id = 1; // TODO: generate an acutal unique ID
	int dev_num   = 1; // TODO: parse name to determine actual dev num
	CcipDevice *ccip_dev = new CcipDevice(dev_num, unique_id);

	if(ccip_dev->is_initialized()) {
		ccip_dev_global = ccip_dev;
	} else {
		delete ccip_dev;
	}

	return 1;   // TODO: return an actual unique ID for handle
}

int AOCL_MMD_CALL  aocl_mmd_close(int handle)
{
	printf("aocl_mmd_close is not implemented\n");
	exit(1);
	return 0;
}

