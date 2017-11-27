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

#include <assert.h>

#include <iostream>
#include <iomanip>
#include <sstream>
#include <limits>
#include <fstream>

#include "ccip_mmd_device.h"
#include "fpgaconf.h"

#define MMD_COPY_BUFFER_SIZE (1024*1024)

using namespace intel_opae_mmd;

int CcipDevice::next_mmd_handle{1};

std::string CcipDevice::get_board_name(std::string prefix, uint64_t obj_id)
{
   std::ostringstream stream;
   stream << prefix << "_" << std::setbase(16) << obj_id;
   return stream.str();
}

// TODO: Need more robust string parsing and need to ensure 
// get_board_name produces output that can be parsed by
// parse_board_name
uint64_t CcipDevice::parse_board_name(const char *board_name)
{
   std::string device_num_str(&board_name[4]); // FIXME: need better parsing
   uint64_t device_num = std::stoul(device_num_str,0,16);
   return device_num;
}

CcipDevice::CcipDevice(uint64_t obj_id):
   fpga_obj_id(obj_id),
   kernel_interrupt_thread(NULL),
   event_update(NULL),
   event_update_user_data(NULL),
   fme_sysfs_temp_initialized(false),
   bus(0),
   device(0),
   function(0),
   afu_initialized(false),
   bsp_initialized(false),
   mmio_is_mapped(false),
   afc_handle(NULL),
   filter(NULL),
   afc_token(NULL),
   dma_h(NULL),
   mmd_copy_buffer(NULL)
{
   // Note that this constructor is not thread-safe because next_mmd_handle
   // is shared between all class instances
   mmd_handle = next_mmd_handle;
   if(next_mmd_handle == std::numeric_limits<int>::max())
      next_mmd_handle = 1;
   else
      next_mmd_handle++;

  mmd_copy_buffer = (char *)malloc(MMD_COPY_BUFFER_SIZE);
  if(mmd_copy_buffer == NULL) {
  	  fprintf(stderr, "malloc failed for mmd_copy_buffer\n");
  	  return;
  }
  
   fpga_guid guid;
   fpga_result res = FPGA_OK;
   uint32_t num_matches;
   
   if (uuid_parse(DCP_OPENCL_DDR_AFU_ID, guid) < 0) {
      fprintf(stderr, "Error parsing guid '%s'\n", DCP_OPENCL_DDR_AFU_ID);
      return;
   }

   res = fpgaGetProperties(NULL, &filter);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error creating properties object\n");
      return;
   }

   res = fpgaPropertiesSetObjectType(filter, FPGA_ACCELERATOR);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error setting object type\n");
      return;
   }

   res = fpgaPropertiesSetObjectID(filter, obj_id);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error setting object ID: %s\n", fpgaErrStr(res));
      return;
   }

   res = fpgaEnumerate(&filter, 1, &afc_token, 1, &num_matches);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error enumerating AFCs: %s\n", fpgaErrStr(res));
      return;
   }

   if(num_matches < 1) {
      fprintf(stderr, "AFC not found\n");
      res = fpgaDestroyProperties(&filter);
      return;
   }

   res = fpgaOpen(afc_token, &afc_handle, 0);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error opening AFC: %s\n", fpgaErrStr(res));
      return;
   }

   fpga_properties prop = nullptr;
   res = fpgaGetProperties(afc_token, &prop);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error reading properties: %s\n", fpgaErrStr(res));
   }

   if(prop) {
      res = fpgaPropertiesGetBus(prop, &bus);
      if(res != FPGA_OK) {
         fprintf(stderr, "Error reading bus: '%s'\n", fpgaErrStr(res));
      }
      res = fpgaPropertiesGetDevice(prop, &device);
      if(res != FPGA_OK) {
         fprintf(stderr, "Error reading device: '%s'\n", fpgaErrStr(res));
      }
      fpgaPropertiesGetFunction(prop, &function);
      if(res != FPGA_OK) {
         fprintf(stderr, "Error reading function: '%s'\n", fpgaErrStr(res));
      }
      fpgaDestroyProperties(&prop);
   }

   // HACK: for now read temperature directly from sysfs.  Initialization
   // logic encapsulted here so it can easily removed laster
   initialize_fme_sysfs();

   mmd_dev_name = get_board_name(BSP_NAME, obj_id);
   afu_initialized = true;
}

void CcipDevice::initialize_fme_sysfs() {
   const int MAX_LEN = 250;
   char fmepath[MAX_LEN];
   
   // HACK: currently ObjectID is constructed using its lower 20 bits
   // as the device minor number.  The device minor number also matches
   // the device ID in sysfs.  This is a simple way to construct a path
   // to the device FME using information that is already available (object_id).
   // Eventually this code should be replaced with a direct call to OPAE C API,
   // but API does not currently expose the device temperature.
   int dev_num = 0xFFFFF & fpga_obj_id;
   snprintf(fmepath, MAX_LEN, 
            "/sys/class/fpga/intel-fpga-dev.%d/intel-fpga-fme.%d/thermal_mgmt/temperature", 
            dev_num, dev_num
            );

   // Try to open the sysfs file. If open succeeds then set as initialized 
   // to be able to read temperature in future.  If open fails then not 
   // initalized and skip attempt to read temperature in future.
   FILE *tmp;
   tmp = fopen(fmepath, "r");
   if(tmp) {
      fme_sysfs_temp_path = std::string(fmepath);
      fme_sysfs_temp_initialized = true;
      fclose(tmp);
   }
}

bool CcipDevice::initialize_bsp()
{
   if(bsp_initialized) {
      return true;
   }

	fpga_result res = fpgaMapMMIO(afc_handle, 0, NULL);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error mapping MMIO space: %d\n", res);
		return false;
	}
	mmio_is_mapped = true;

	/* Reset AFC */
	res = fpgaReset(afc_handle);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error resetting AFC: %d\n", res);
		return false;
	}
	AFU_RESET_DELAY();
	
	dma_h = new mmd_dma(afc_handle, mmd_handle);
	if(!dma_h->initialized())
	{
		fprintf(stderr, "Error initializing mmd dma\n");
		return false;
	}
	
	kernel_interrupt_thread = new KernelInterrupt(afc_handle, mmd_handle);
	
	if(!kernel_interrupt_thread->initialized())
	{
		fprintf(stderr, "Error initializing kernel interrupts\n");
		return false;
	}
	
	bsp_initialized = true;
	return bsp_initialized;
}

CcipDevice::~CcipDevice()
{
	int num_errors = 0;
	if(mmd_copy_buffer) {
		free(mmd_copy_buffer);
		mmd_copy_buffer = NULL;
    }
	
	if(kernel_interrupt_thread)
	{
		delete kernel_interrupt_thread;
		kernel_interrupt_thread = NULL;
	}
	
	if(dma_h)
	{
		delete dma_h;
		dma_h = NULL;
	}

	if(mmio_is_mapped)
	{
		if(fpgaUnmapMMIO(afc_handle, 0))
			num_errors++;
	}
	
	if(afc_handle) {
		if(fpgaClose(afc_handle) != FPGA_OK)
			num_errors++;
	}
	
	if(afc_token) {
		if(fpgaDestroyToken(&afc_token) != FPGA_OK)
			num_errors++;
	}

	if(filter) {
		if(fpgaDestroyProperties(&filter) != FPGA_OK)
			num_errors++;
	}

	if(num_errors > 0) {
		DEBUG_PRINT("Error freeing resources in destructor\n");
	}

}

int CcipDevice::program_bitstream(uint8_t *data, size_t data_size)
{
   if(!afu_initialized) {
      return FPGA_NOT_FOUND;
   }

   assert(data);
   
   if(kernel_interrupt_thread)
   {
   	   kernel_interrupt_thread->disable_interrupts();
   }

   find_fpga_target target = { bus, device, function, -1 }; 
   fpga_token fpga_dev;
   int num_found = find_fpga(target, &fpga_dev);
  
   int res;
   if(num_found == 1) {
      res =  program_gbs_bitstream(fpga_dev, data, data_size);
   } else {
      fprintf(stderr, "Error programming FPGA\n");
      res = -1;
   }

   fpgaDestroyToken(&fpga_dev);
   
   if(kernel_interrupt_thread)
   {
   	  kernel_interrupt_thread->enable_interrupts();
      if(!kernel_interrupt_thread->initialized())
      {
         fprintf(stderr, "Error initializing kernel interrupts\n");
         return false;
      }
   }
   
   if(dma_h)
   {
	   dma_h->reinit_dma();
	   if(!dma_h->initialized())
	   {
		  fprintf(stderr, "Error initializing DMA\n");
		  return false;
	   }
   }
   
   return res;
}


int CcipDevice::yield() {
	if(kernel_interrupt_thread)
		kernel_interrupt_thread->yield();
	return 0;
}


bool CcipDevice::bsp_loaded() {
   fpga_guid dcp_guid;
   fpga_guid afu_guid;
   fpga_properties   prop;
   fpga_result res;

   if (uuid_parse(DCP_OPENCL_DDR_AFU_ID, dcp_guid) < 0) {
      fprintf(stderr, "Error parsing guid '%s'\n", DCP_OPENCL_DDR_AFU_ID);
      return false;
   }
 
   res = fpgaGetProperties(afc_token, &prop);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error reading properties: %s\n", fpgaErrStr(res));
      fpgaDestroyProperties(&prop);
      return false;
   }

   res = fpgaPropertiesGetGUID(prop, &afu_guid);
   if(res != FPGA_OK) {
      fprintf(stderr, "Error reading GUID\n");
      fpgaDestroyProperties(&prop);
      return false;
   } 

   fpgaDestroyProperties(&prop);
   if(uuid_compare(dcp_guid, afu_guid) == 0) {
      return true;
   } else {
      return false;
   }
}

std::string CcipDevice::get_bdf() {
   std::ostringstream bdf;
   bdf << std::setfill('0') << std::setw(2) << unsigned(bus) << ":"
       << std::setfill('0') << std::setw(2) << unsigned(device) << "."
       << unsigned(function);

   return bdf.str();
}

float CcipDevice::get_temperature() {
   float temp = 0;
   if(fme_sysfs_temp_initialized) {
      std::ifstream sysfs_temp(fme_sysfs_temp_path, std::ifstream::in);
      sysfs_temp >> temp;
      sysfs_temp.close();
   }
   return temp;
}
 
void CcipDevice::set_kernel_interrupt(aocl_mmd_interrupt_handler_fn fn, void* user_data)
{
	if(kernel_interrupt_thread)
	{
		kernel_interrupt_thread->set_kernel_interrupt(fn, user_data);
	}
}

void CcipDevice::set_status_handler(aocl_mmd_status_handler_fn fn, void *user_data)
{
	event_update = fn;
	event_update_user_data = user_data;
	dma_h->set_status_handler(fn, user_data);
}

void CcipDevice::event_update_fn(aocl_mmd_op_t op, int status)
{
	event_update(mmd_handle, event_update_user_data, op, status);
}

int CcipDevice::read_block(aocl_mmd_op_t op, int mmd_interface, void *host_addr, size_t offset, size_t size)
{
	int status = -1;

	// The mmd_interface is defined as the base address of the MMIO write.  Access
	// to memory requires special functionality.  Otherwise do direct MMIO read of
	// base address + offset
	if(mmd_interface == AOCL_MMD_MEMORY) {
		status = dma_h->read_memory(op, static_cast<uint64_t *>(host_addr), offset, size);
	} else {
		status = read_mmio(host_addr, mmd_interface + offset, size);
		
		if(op) {
			//TODO: check what status value should really be instead of just using 0
			//Also handle case when op is NULL
			this->event_update_fn(op, 0);
		}
	}

	//TODO: check what status values aocl wants and also parse the result
	if(status != FPGA_OK) {
		DEBUG_PRINT("read_block error code: %d\n", status);
		return -1;
	} else {
		return 0;
	}
}

int CcipDevice::write_block(aocl_mmd_op_t op, int mmd_interface, const void *host_addr, size_t offset, size_t size)
{
	int status = -1;

	// The mmd_interface is defined as the base address of the MMIO write.  Access
	// to memory requires special functionality.  Otherwise do direct MMIO write
	if(mmd_interface == AOCL_MMD_MEMORY) {
		status = dma_h->write_memory(op, static_cast<const uint64_t *>(host_addr), offset, size);
	} else {
		status = write_mmio(host_addr, mmd_interface + offset, size);
		
		if(op) {
			//TODO: check what 'status' value should really be.  Right now just
			//using 0 as was done in previous CCIP MMD.  Also handle case if op is NULL
			this->event_update_fn(op, 0);
		}
	}

	//TODO: check what status values aocl wants and also parse the result
	if(status != FPGA_OK) {
		DEBUG_PRINT("write_block error code: %d\n", status);
		return -1;
	} else {
		return 0;
	}
}

int CcipDevice::copy_block(aocl_mmd_op_t op,
		int mmd_interface,
		size_t src_offset, size_t dst_offset,
		size_t size)
{
	int status = -1;
	
	if(mmd_interface == AOCL_MMD_MEMORY) {
		size_t bytes_left = size;
		size_t read_offset = src_offset;
		size_t write_offset = dst_offset;
		while(bytes_left != 0) {
			size_t chunk = bytes_left > MMD_COPY_BUFFER_SIZE ? MMD_COPY_BUFFER_SIZE : bytes_left;
			
			//for now, just to reads and writes to/from host to implement this
			//DMA hw can support direct copy but we don't have time to verify
			//that so close to the release.
			//also this API is rarely used.
			status = read_block(NULL, AOCL_MMD_MEMORY, mmd_copy_buffer, read_offset, chunk);
			if(status != 0)
				break;
			status = write_block(NULL, AOCL_MMD_MEMORY, mmd_copy_buffer, write_offset, chunk);
			if(status != 0)
				break;
			read_offset += chunk;
			write_offset += chunk;
			bytes_left -= chunk;
		}
		status = 0;
	} else {
		DEBUG_PRINT("copy_block unsupported mmd_interface: %d\n", mmd_interface);
		status = -1;
	}
	
	
	if(op) {
		//TODO: check what 'status' value should really be.  Right now just
		//using 0 as was done in previous CCIP MMD.  Also handle case if op is NULL
		this->event_update_fn(op, 0);
	}
	
	return status;
}

int CcipDevice::read_mmio(void *host_addr, size_t mmio_addr, size_t size)
{
	fpga_result res = FPGA_OK;

	DCP_DEBUG_MEM("read_mmio start: %p\t %lx\t %lu\n", host_addr, mmio_addr, size);

	//HACK: need extra delay for opencl sw reset
	if(mmio_addr == KERNEL_SW_RESET_BASE)
		OPENCL_SW_RESET_DELAY();

	uint64_t *host_addr64 = static_cast<uint64_t *>(host_addr);
	while(size >= 8) {
		res = fpgaReadMMIO64(afc_handle, 0, mmio_addr, host_addr64);
		if(res != FPGA_OK)
			return res;
		host_addr64 += 1;
		mmio_addr += 8;
		size -= 8;
	}

	uint32_t *host_addr32 = reinterpret_cast<uint32_t *>(host_addr64);
	while(size >= 4) {
		res = fpgaReadMMIO32(afc_handle, 0, mmio_addr, host_addr32);
		if(res != FPGA_OK)
			return res;
		host_addr32 += 1;
		mmio_addr += 4;
		size -= 4;
	}

	if(size > 0) {
		uint32_t read_data;
		res = fpgaReadMMIO32(afc_handle, 0, mmio_addr, &read_data);
		if(res != FPGA_OK)
			return res;
		memcpy(host_addr32, &read_data, size);
	}

	return res;
}


int CcipDevice::write_mmio(const void *host_addr, size_t mmio_addr, size_t size)
{
	fpga_result res = FPGA_OK;

	DEBUG_PRINT("write_mmio\n");

	//HACK: need extra delay for opencl sw reset
	if(mmio_addr == KERNEL_SW_RESET_BASE)
		OPENCL_SW_RESET_DELAY();

	const uint64_t *host_addr64 = static_cast<const uint64_t *>(host_addr);
	while(size >= 8) {
		res = fpgaWriteMMIO64(afc_handle, 0, mmio_addr, *host_addr64);
		if(res != FPGA_OK)
			return res;
		host_addr64 += 1;
		mmio_addr += 8;
		size -= 8;
	}

	const uint32_t *host_addr32 = reinterpret_cast<const uint32_t *>(host_addr64);
	while(size > 0) {
		uint32_t tmp_data32 = 0;
		size_t chunk_size = (size >= 4) ? 4 : size;
		memcpy(&tmp_data32, host_addr32, chunk_size);
		res = fpgaWriteMMIO32(afc_handle, 0, mmio_addr, tmp_data32);
		if(res != FPGA_OK)
			return res;
		host_addr32 += 1;
		mmio_addr += chunk_size;
		size -= chunk_size;
	}

	return res;
}

