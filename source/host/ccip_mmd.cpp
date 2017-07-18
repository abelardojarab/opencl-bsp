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

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <zlib.h>

#include <sstream> 

#include "aocl_mmd.h"
#include "ccip_mmd_device.h"
#include "zlib_inflate.h"
#include "fpgaconf.h"

#define ACL_DCP_ERROR_IF(COND,NEXT,...) \
   do { if ( COND )  { \
      printf("\nMMD ERROR: " __VA_ARGS__); fflush(stdout); NEXT; } \
   } while(0)

#define ACL_PKG_SECTION_DCP_GBS_GZ	".acl.gbs.gz"

//since we only support 1 device at a time, we always return 1 as the handle
#define AOCL_INVALID_HANDLE 	-1
#define AOCL_DEFAULT_HANDLE 	1

// TODO: create map or some other data structure that supports multiple devices
// and replace all uses of ccip_dev_global with appropriate lookup function
CcipDevice *ccip_dev_global = NULL;

// static helper functions
static bool check_for_svm_env();

//HACK: needed for reprogram to know if opencl image is loaded
//opencl runtime gets confused if there is no opencl image loaded
bool ccip_mmd_is_fpga_configured_with_opencl()
{
	fpga_guid guid;
	fpga_result res = FPGA_OK;
	uint32_t num_matches = 0;
	fpga_properties   filter;
	fpga_token        afc_token;

	if (uuid_parse(DCP_OPENCL_DDR_AFU_ID, guid) < 0) {
		fprintf(stderr, "Error parsing guid '%s'\n", DCP_OPENCL_DDR_AFU_ID);
		return false;
	}

	res = fpgaGetProperties(NULL, &filter);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error creating properties object\n");
		return false;
	}

	res = fpgaPropertiesSetObjectType(filter, FPGA_AFC);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error setting object type\n");
		return false;
	}

	res = fpgaPropertiesSetGUID(filter, guid);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error setting GUID\n");
		return false;
	}

	//TODO: Add selection via BDF / device ID
	res = fpgaEnumerate(&filter, 1, &afc_token, 1, &num_matches);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error enumerating AFCs: %d\n", res);
		return false;
	}

	if(afc_token)
		fpgaDestroyToken(&afc_token);
	
	if(filter)
		fpgaDestroyProperties(&filter);
	
	return (num_matches >= 1);
}

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
	DCP_DEBUG_MEM("\n+ aocl_mmd_reprogram: handle=%d data=%p data_size=%d\n", handle, data, data_size);
	
	struct acl_pkg_file *pkg = acl_pkg_open_file_from_memory( (char*)data, data_size, ACL_PKG_SHOW_ERROR );
	struct acl_pkg_file *fpga_bin_pkg = NULL;
	struct acl_pkg_file *search_pkg = pkg;
	ACL_DCP_ERROR_IF(pkg == NULL, return AOCL_INVALID_HANDLE, "cannot open file from memory using pkg editor.\n");
	
	//need to handle aocx files directly for calling this API directly instead
	//of through the OpenCL runtime
	size_t fpga_bin_len = 0;
	char *fpga_bin_contents = NULL;
	if(acl_pkg_section_exists( pkg, ACL_PKG_SECTION_FPGA_BIN, &fpga_bin_len ) &&
		acl_pkg_read_section_transient(pkg, ACL_PKG_SECTION_FPGA_BIN, &fpga_bin_contents))
	{
		fpga_bin_pkg = acl_pkg_open_file_from_memory( (char*)fpga_bin_contents, fpga_bin_len, ACL_PKG_SHOW_ERROR );
		search_pkg = fpga_bin_pkg;
	}
	
	//check for compressed GBS and attempt to load it
	size_t acl_gbs_gz_len = 0;
	char *acl_gbs_gz_contents = NULL;
	if(acl_pkg_section_exists( search_pkg, ACL_PKG_SECTION_DCP_GBS_GZ, &acl_gbs_gz_len ) &&
		acl_pkg_read_section_transient(search_pkg, ACL_PKG_SECTION_DCP_GBS_GZ, &acl_gbs_gz_contents))
	{
		void *gbs_data = NULL;
		size_t gbs_data_size = 0;
		int ret = inf(acl_gbs_gz_contents, acl_gbs_gz_len, &gbs_data, &gbs_data_size);
		ACL_DCP_ERROR_IF(ret != Z_OK, return AOCL_INVALID_HANDLE, "aocl_mmd_reprogram error: GBS decompression failed!\n");
		
		if(ccip_dev_global)
		{
			delete ccip_dev_global;
			ccip_dev_global = NULL;
		}
		
		//this will need to match input device handle
		find_fpga_target target = {-1, -1, -1, -1};
		fpga_token fpga_dev;
		int num_found = find_fpga(target, &fpga_dev);
		ACL_DCP_ERROR_IF(num_found == 0, return AOCL_INVALID_HANDLE, "FPGA device not found for reconfiguration!\n");
		
		//Do config
		int programming_result = program_gbs_bitstream(fpga_dev, (uint8_t *)gbs_data, gbs_data_size);

		//clean up
		fpgaDestroyToken(&fpga_dev);
		
		if(gbs_data)
			free(gbs_data);
		
		if ( pkg ) acl_pkg_close_file(pkg);
		if ( fpga_bin_pkg ) acl_pkg_close_file(fpga_bin_pkg);
		
		ACL_DCP_ERROR_IF(programming_result != FPGA_OK, return AOCL_INVALID_HANDLE, "FPGA programming failed!\n");

		return aocl_mmd_open("acl0");
	}

	return AOCL_INVALID_HANDLE;
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
		case AOCL_MMD_BOARD_NAME:            
		{
			std::ostringstream board_name;
			//TODO: fix this for multiboard support
			board_name << "SKX DCP FPGA OpenCL BSP" << " (" << "acl0" << ")";
			RESULT_STR(board_name.str().c_str()); 
			break;
		}
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

	CcipDevice *ccip_dev = new CcipDevice();

	if(ccip_dev->is_initialized()) {
		ccip_dev_global = ccip_dev;
	} else {
		delete ccip_dev;
		return AOCL_INVALID_HANDLE;
	}

	return AOCL_DEFAULT_HANDLE;   // TODO: return an actual unique ID for handle
}

int AOCL_MMD_CALL  aocl_mmd_close(int handle)
{
	if(ccip_dev_global)
	{
		delete ccip_dev_global;
		ccip_dev_global = NULL;
	}
	return 0;
}
