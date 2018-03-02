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

#include <iomanip>
#include <iostream>
#include <cassert>
#include <sstream> 
#include <map>

#include <safe_string/safe_string.h>
#include "memcpy_s_fast.h"

#include "aocl_mmd.h"
#include "ccip_mmd_device.h"
#include "zlib_inflate.h"
#include "fpgaconf.h"
#include "test_perm.h"

using namespace intel_opae_mmd;

#define ACL_DCP_ERROR_IF(COND,NEXT,...) \
   do { if ( COND )  { \
      printf("\nMMD ERROR: " __VA_ARGS__); fflush(stdout); NEXT; } \
   } while(0)

#define ACL_PKG_SECTION_DCP_GBS_GZ	".acl.gbs.gz"

#define AOCL_INVALID_HANDLE 	-1

// Mapping from OPAE obj ID to MMD handle
static std::map<int, CcipDevice*> bsp_devices;
static std::map<uint64_t, int> obj_handle_map;

static inline int get_handle(uint64_t obj_id)
{
   auto it = obj_handle_map.find(obj_id);
   if(it != obj_handle_map.end()) {
      return it->second;
   } else {
      return AOCL_INVALID_HANDLE;
   }
}

static CcipDevice *get_device(int handle)
{
   auto it = bsp_devices.find(handle);
   if(it != bsp_devices.end()) {
      return it->second;
   } else {
      return NULL;
   }
}


// static helper functions
#if 0
static bool check_for_svm_env();
#endif


// Interface for programing device that does not have a BSP loaded
int ccip_mmd_device_reprogram(const char *device_name, void *data, size_t data_size)
{
   uint64_t obj_id = CcipDevice::parse_board_name(device_name);
   
   int handle = get_handle(obj_id);
   if(handle == -1) {
      CcipDevice *dev = new CcipDevice(obj_id);
      handle = dev->get_mmd_handle();
      bsp_devices[handle] = dev;
      obj_handle_map[obj_id] = handle;
   }
   
   return aocl_mmd_reprogram(handle, data, data_size); 
}

// Interface for checking if AFU has BSP loaded
bool ccip_mmd_bsp_loaded(const char *name)
{
   uint64_t obj_id = CcipDevice::parse_board_name(name);
   if(!obj_id) {
      return false;
   }

   int handle = get_handle(obj_id);
   if(handle > 0) {
      CcipDevice *dev = get_device(handle);
      if(dev)
         return dev->bsp_loaded(); 
      else 
         return false;
   } else {
      CcipDevice dev(obj_id);
      return dev.bsp_loaded();
   } 
}


static unsigned int get_offline_num_acl_boards() 
{
   fpga_result res = FPGA_OK;
   uint32_t num_matches = 0;
   fpga_properties   filter;

   res = fpgaGetProperties(NULL, &filter);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error creating properties object\n");
      goto out;
   }

   res = fpgaPropertiesSetObjectType(filter, FPGA_ACCELERATOR);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error setting object type\n");
      goto out;
   }

   res = fpgaEnumerate(&filter, 1, NULL, 0, &num_matches);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error enumerating AFCs: %d\n", res);
      goto out;
   }

out:
   if(filter)
      fpgaDestroyProperties(&filter);

   return num_matches;

}	

static std::string get_offline_board_names()
{
   fpga_guid dcp_guid;
   fpga_result res = FPGA_OK;
   uint32_t num_matches = 0;
   fpga_properties   filter = nullptr;
   fpga_properties   prop = nullptr;
   std::string boards = std::string();
   std::ostringstream board_name;
   fpga_token *toks = nullptr;
   fpga_guid afu_guid;
   uint64_t obj_id;
   
   if (uuid_parse(DCP_OPENCL_DDR_AFU_ID, dcp_guid) < 0) {
      fprintf(stderr, "Error parsing guid '%s'\n", DCP_OPENCL_DDR_AFU_ID);
      goto cleanup;
   }

   res = fpgaGetProperties(NULL, &filter);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error creating properties object\n");
      goto cleanup;
   }

   res = fpgaPropertiesSetObjectType(filter, FPGA_ACCELERATOR);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error setting object type\n");
      goto cleanup;
   }

   res = fpgaEnumerate(&filter, 1, NULL, 0, &num_matches);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error enumerating AFCs: %d\n", res);
      goto cleanup;
   }

   toks = static_cast<fpga_token *>(malloc(num_matches * sizeof(fpga_token)));
   if(toks == NULL) {
      fprintf(stderr, "Error allocating memory\n");
      goto cleanup;
   }
   
   res = fpgaEnumerate(&filter, 1, toks, num_matches, &num_matches); 
   if(res != FPGA_OK) {
      fprintf(stderr, "Error enumerating AFCs: %d\n", res);
      goto cleanup;
   }

   for(unsigned int i = 0; i < num_matches; i++) {
      if(prop)
         fpgaDestroyProperties(&prop);
      res = fpgaGetProperties(toks[i], &prop);
      if(res == FPGA_OK) {
         res = fpgaPropertiesGetGUID(prop, &afu_guid);
         if(res != FPGA_OK) {
            fprintf(stderr, "Error reading GUID\n");
            break;
         }

         // TODO: determine if boards with BSP loaded should have different name
         // if not then simplify this code
         std::string prefix;
         if(uuid_compare(dcp_guid, afu_guid) == 0) {
             prefix = BSP_NAME;
         } else {
             prefix = BSP_NAME;
         }

         res = fpgaPropertiesGetObjectID(prop, &obj_id);
         if(res != FPGA_OK) {
            fprintf(stderr, "Error reading object ID\n");
            break;
         }
         boards.append(CcipDevice::get_board_name(prefix, obj_id));
         if( i < num_matches - 1)
            boards.append(";");
      } else {
         fprintf(stderr,"Error reading properties: %s\n", fpgaErrStr(res));
      }
   }

cleanup:
   if(prop)
      fpgaDestroyProperties(&prop);
   if(filter)
      fpgaDestroyProperties(&filter);
   if(toks)
      free(toks);
   return boards;
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
   CcipDevice *afu = get_device(handle);
   if(afu == NULL) {
      fprintf(stderr, "aocl_mmd_reprogram: invalid handle: %d\n", handle);
      return AOCL_INVALID_HANDLE;
   }

	struct acl_pkg_file *pkg = acl_pkg_open_file_from_memory( (char*)data, data_size, ACL_PKG_SHOW_ERROR );
	struct acl_pkg_file *fpga_bin_pkg = NULL;
	struct acl_pkg_file *search_pkg = pkg;
	ACL_DCP_ERROR_IF(pkg == NULL, return AOCL_INVALID_HANDLE, "cannot open file from memory using pkg editor.\n");
	
   // extract bin file from aocx
	size_t fpga_bin_len = 0;
	char *fpga_bin_contents = NULL;
	if(acl_pkg_section_exists( pkg, ACL_PKG_SECTION_FPGA_BIN, &fpga_bin_len ) &&
		acl_pkg_read_section_transient(pkg, ACL_PKG_SECTION_FPGA_BIN, &fpga_bin_contents))
	{
		fpga_bin_pkg = acl_pkg_open_file_from_memory( (char*)fpga_bin_contents, fpga_bin_len, ACL_PKG_SHOW_ERROR );
		search_pkg = fpga_bin_pkg;
	}
	
	// load compressed gbs
	size_t acl_gbs_gz_len = 0;
	char *acl_gbs_gz_contents = NULL;
	if(acl_pkg_section_exists( search_pkg, ACL_PKG_SECTION_DCP_GBS_GZ, &acl_gbs_gz_len ) &&
		acl_pkg_read_section_transient(search_pkg, ACL_PKG_SECTION_DCP_GBS_GZ, &acl_gbs_gz_contents))
	{
		void *gbs_data = NULL;
		size_t gbs_data_size = 0;
		int ret = inf(acl_gbs_gz_contents, acl_gbs_gz_len, &gbs_data, &gbs_data_size);

		if(ret != Z_OK) {
          fprintf(stderr,"aocl_mmd_reprogram error: GBS decompression failed!\n");
          if(gbs_data)
             free(gbs_data);
          return AOCL_INVALID_HANDLE;
      }
		
		int res = afu->program_bitstream(static_cast<uint8_t *>(gbs_data), gbs_data_size);
		
		if(gbs_data)
			free(gbs_data);
		
		if ( pkg ) acl_pkg_close_file(pkg);
		if ( fpga_bin_pkg ) acl_pkg_close_file(fpga_bin_pkg);
		
		if(res != 0)
		{
			ccip_mmd_dma_setup_check();
			ccip_mmd_check_fme_driver_for_pr();
			return AOCL_INVALID_HANDLE;
		}

        return handle;
	}

	return AOCL_INVALID_HANDLE;
}

int AOCL_MMD_CALL aocl_mmd_yield(int handle)
{
	DEBUG_PRINT("* Called: aocl_mmd_yield\n");
	YIELD_DELAY();

   CcipDevice *dev = get_device(handle);
   assert(dev);
   dev->yield();

	return 0;
}

// TODO: determine if svm is used at all (i.e. in testing).  Otherwise
// consider removing
#if 0
static bool check_for_svm_env()
{
	//SVM not yet supported so no reason to check right now
#ifndef ENABLE_SVM
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
#endif


// Macros used for acol_mmd_get_offline_info and aocl_mmd_get_info
#define RESULT_INT(X) {*((int*)param_value) = X; if (param_size_ret) *param_size_ret=sizeof(int);}
#define RESULT_STR(X) do { \
	unsigned Xlen = strlen(X) + 1; \
   unsigned Xcpylen = (param_value_size <= Xlen) ? param_value_size : Xlen; \
	memcpy_s_fast((void*)param_value, param_value_size, X, Xcpylen); \
	if (param_size_ret) *param_size_ret=Xcpylen; \
} while(0)


int aocl_mmd_get_offline_info(
		aocl_mmd_offline_info_t requested_info_id,
		size_t param_value_size,
		void* param_value,
		size_t* param_size_ret )
{
	int mem_type_info = (int)AOCL_MMD_PHYSICAL_MEMORY;

// TODO: determine if svm is used at all (i.e. in testing).  Otherwise
// consider removing
#if 0
	if(check_for_svm_env())
		mem_type_info = (int)AOCL_MMD_SVM_COARSE_GRAIN_BUFFER;
#endif

   unsigned int num_acl_boards;

	switch(requested_info_id)
	{
		case AOCL_MMD_VERSION:              RESULT_STR("14.1"); break;
		case AOCL_MMD_NUM_BOARDS:
		{
			num_acl_boards = get_offline_num_acl_boards();
		   RESULT_INT(num_acl_boards); 
			break;
		}
		case AOCL_MMD_VENDOR_NAME:          RESULT_STR("Intel Corp"); break;
		case AOCL_MMD_BOARD_NAMES:
      {
         std::ostringstream boards;
         boards << get_offline_board_names();
         RESULT_STR(boards.str().c_str()); 
         break;
      }
		case AOCL_MMD_VENDOR_ID:            RESULT_INT(0); break;
		case AOCL_MMD_USES_YIELD:           RESULT_INT(KernelInterrupt::yield_is_enabled()); break;
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
   CcipDevice *dev = get_device(handle);
   if(dev == NULL)
      return 0;

   assert(param_value);
	switch(requested_info_id)
	{
		case AOCL_MMD_BOARD_NAME:            
		{
			std::ostringstream board_name;
			board_name << "PAC Arria 10 Platform" << " (" << dev->get_dev_name() << ")";
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
      case AOCL_MMD_PCIE_INFO:        
      {
         RESULT_STR(dev->get_bdf().c_str());
         break;
      }
		case AOCL_MMD_BOARD_UNIQUE_ID:       RESULT_INT(0); break;
		case AOCL_MMD_TEMPERATURE:
						     {
                          if(param_value_size == sizeof(float)) {
                             float *ptr = static_cast<float *>(param_value);
                             *ptr = dev->get_temperature();
                             if(param_size_ret)
                                *param_size_ret = sizeof(float);
                          }
                          break;
						     }
	}
	return 0;
}

#undef RESULT_INT
#undef RESULT_STR

int AOCL_MMD_CALL aocl_mmd_set_interrupt_handler( int handle, aocl_mmd_interrupt_handler_fn fn, void* user_data )
{
   CcipDevice *dev = get_device(handle);
   if(dev)
	   dev->set_kernel_interrupt(fn, user_data);
      //TODO: handle error condition if dev null
	return 0;
}

int AOCL_MMD_CALL aocl_mmd_set_status_handler( int handle, aocl_mmd_status_handler_fn fn, void* user_data )
{
   CcipDevice *dev = get_device(handle);
   if(dev)
	   dev->set_status_handler(fn, user_data);
      //TODO: handle error condition if dev null
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
   CcipDevice *dev = get_device(handle);
   if(dev)
      return dev->write_block(op, mmd_interface, src, offset, len);
   else
      return -1;
      //TODO: handle error condition if dev null
   

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
   CcipDevice *dev = get_device(handle);
   if(dev)
	   return dev->read_block(op, mmd_interface, dst, offset, len);
   else
      return -1;
      //TODO: handle error condition if dev null
}

int AOCL_MMD_CALL aocl_mmd_copy(
		int handle,
		aocl_mmd_op_t op,
		size_t len,
		int mmd_interface, size_t src_offset, size_t dst_offset )
{
   DCP_DEBUG_MEM("\n+ aocl_mmd_copy: %d\t %p\t %lu\t %d\t %lu %lu\n",handle, op, len, mmd_interface, src_offset, dst_offset);
   CcipDevice *dev = get_device(handle);
   if(dev)
	   return dev->copy_block(op, mmd_interface, src_offset, dst_offset, len);
   else
      return -1;
      //TODO: handle error condition if dev null
}

int AOCL_MMD_CALL aocl_mmd_open(const char *name)
{
	DEBUG_PRINT("Opening device: %s\n", name);
 
   uint64_t obj_id = CcipDevice::parse_board_name(name);
   if(!obj_id) {
      return AOCL_INVALID_HANDLE;
   }

   int handle = get_handle(obj_id);
   CcipDevice *dev = nullptr;
   if(handle > 0) {
      dev = get_device(handle);
   } else {
      dev = new CcipDevice(obj_id);
      handle = dev->get_mmd_handle();
      bsp_devices[handle] = dev;
   } 

   assert(dev);
   if(dev->bsp_loaded()) { 
      if(!dev->initialize_bsp())
      {
      	  handle = ~handle;
      	  fprintf(stderr, "Error initializing bsp\n");
      }
   } else {
      handle = ~handle;
   }
	return handle;
}

int AOCL_MMD_CALL  aocl_mmd_close(int handle)
{
   CcipDevice *dev = get_device(handle);
	if(dev)
	{
      assert(dev->get_mmd_handle() == handle);
      uint64_t obj_id = dev->get_fpga_obj_id();
     
      auto obj_it = obj_handle_map.find(obj_id);
      obj_handle_map.erase(obj_it);

      auto handle_it = bsp_devices.find(handle);
      bsp_devices.erase(handle_it);
       
		delete dev;
	}
	return 0;
}

