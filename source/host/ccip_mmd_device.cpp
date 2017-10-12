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

#include <limits>
#include <mutex>

#include "ccip_mmd_device.h"
#include "afu_bbb_util.h"
#include "fpgaconf.h"

//for DDR through MMIO
#define MEM_WINDOW_CRTL 0x200
#define MEM_WINDOW_MEM 0x1000
#define MEM_WINDOW_SPAN (4*1024)
#define MEM_WINDOW_SPAN_MASK ((long)(MEM_WINDOW_SPAN-1))

#define MINIMUM_DMA_SIZE	256
#define DMA_ALIGNMENT	256

//#define DISABLE_DMA

int CcipDevice::next_mmd_handle{1};
std::mutex CcipDevice::class_lock;

CcipDevice::CcipDevice(uint64_t obj_id):
   fpga_obj_id(obj_id),
   kernel_interrupt(NULL),
   kernel_interrupt_user_data(NULL),
   event_update(NULL),
   event_update_user_data(NULL),
   afu_initialized(false),
   bsp_initialized(false),
   mmio_is_mapped(false),
   afc_handle(NULL),
   filter(NULL),
   afc_token(NULL),
   dma_h(NULL),
   msgdma_bbb_base_addr(0)
{
   // Lock because 'next_mmd_handle' may be shared between threads 
   {  
      std::lock_guard<std::mutex> lock(class_lock);
      mmd_handle = next_mmd_handle;
      if(next_mmd_handle == std::numeric_limits<int>::max())
         next_mmd_handle = 1;
      else
         next_mmd_handle++;
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

   mmd_dev_name = BSP_NAME + std::to_string(obj_id);
   afu_initialized = true;
}

void CcipDevice::initialize_bsp()
{
   if(bsp_initialized) {
      return;
   }

	fpga_result res = fpgaMapMMIO(afc_handle, 0, NULL);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error mapping MMIO space: %d\n", res);
		return;
	}
	mmio_is_mapped = true;

	/* Reset AFC */
	res = fpgaReset(afc_handle);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error resetting AFC: %d\n", res);
		return;
	}
	AFU_RESET_DELAY();
	
	#ifndef DISABLE_DMA
	res = fpgaDmaOpen(afc_handle, &dma_h);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error initializing DMA: %d\n", res);
		return;
	}
	#endif
	
	//need base address for address span extender
	uint64_t dfh_size = 0;
	bool found_dfh = find_dfh_by_guid(afc_handle, MSGDMA_BBB_GUID, &msgdma_bbb_base_addr, &dfh_size);
	if(!found_dfh || dfh_size != MSGDMA_BBB_SIZE) {
		fprintf(stderr, "Error initializing DMA: %d\n", res);
		return;
	}
	
	#ifdef ENABLE_OPENCL_KERNEL_INTERRUPTS
	uint32_t intr_mask = 0x00000001;
	res = fpgaWriteMMIO32(afc_handle, 0, AOCL_IRQ_MASKING_BASE, intr_mask);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error fpgaWriteMMIO32: %d\n", res);
		return;
	}
	#endif
	
	bsp_initialized = true;
}

CcipDevice::~CcipDevice()
{
	int num_errors = 0;
	if(dma_h) {
		if(fpgaDmaClose(dma_h) != FPGA_OK)
			num_errors++;
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
   return res;
}


int CcipDevice::yield() {
   kernel_interrupt(mmd_handle, kernel_interrupt_user_data);
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


void CcipDevice::set_kernel_interrupt(aocl_mmd_interrupt_handler_fn fn, void* user_data)
{
	kernel_interrupt = fn;
	kernel_interrupt_user_data = user_data;
}

void CcipDevice::set_status_handler(aocl_mmd_status_handler_fn fn, void *user_data)
{
	event_update = fn;
	event_update_user_data = user_data;
}

void CcipDevice::event_update_fn(aocl_mmd_op_t op, int status)
{
	event_update(1, event_update_user_data, op, status);
}

int CcipDevice::read_block(aocl_mmd_op_t op, int mmd_interface, void *host_addr, size_t offset, size_t size)
{
	int status = -1;

	// The mmd_interface is defined as the base address of the MMIO write.  Access
	// to memory requires special functionality.  Otherwise do direct MMIO read of
	// base address + offset
	if(mmd_interface == AOCL_MMD_MEMORY) {
		status = read_memory(static_cast<uint64_t *>(host_addr), offset, size);
	} else {
		status = read_mmio(host_addr, mmd_interface + offset, size);
	}

	if(op) {
		//TODO: check what status value should really be instead of just using 0
		//Also handle case when op is NULL
		this->event_update_fn(op, 0);
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
		status = write_memory(static_cast<const uint64_t *>(host_addr), offset, size);
	} else {
		status = write_mmio(host_addr, mmd_interface + offset, size);
	}

	if(op) {
		//TODO: check what 'status' value should really be.  Right now just
		//using 0 as was done in previous CCIP MMD.  Also handle case if op is NULL
		this->event_update_fn(op, 0);
	}

	//TODO: check what status values aocl wants and also parse the result
	if(status != FPGA_OK) {
		DEBUG_PRINT("write_block error code: %d\n", status);
		return -1;
	} else {
		return 0;
	}
}

int CcipDevice::read_memory(uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_MEM("DCP DEBUG: read_memory %p %lx %ld\n", host_addr, dev_addr, size);
	int res = FPGA_OK;
	
	//check for alignment
	if(dev_addr % DMA_ALIGNMENT != 0)
	{
		//check for mmio alignment
		uint64_t mmio_shift = dev_addr % 8;
		if(mmio_shift != 0)
		{
			size_t unaligned_size = 8 - mmio_shift;
			if(unaligned_size > size)
				unaligned_size = size;
			
			read_memory_mmio_unaligned(host_addr, dev_addr, unaligned_size);
			
			if(size > unaligned_size)
				res = read_memory((uint64_t *)(((char *)host_addr)+unaligned_size), dev_addr+unaligned_size, size-unaligned_size);
			return res;
		}
		
		//TODO: need to do a shift here
		return read_memory_mmio(host_addr, dev_addr, size);
	}
	
	//check size
	if(size < MINIMUM_DMA_SIZE)
		return read_memory_mmio(host_addr, dev_addr, size);
	
	size_t remainder = (size % DMA_ALIGNMENT);
	size_t dma_size = size - remainder;
	
	#ifdef DISABLE_DMA
	res = read_memory_mmio(host_addr, dev_addr, dma_size);
	#else
	res = fpgaDmaTransferSync(dma_h, (uint64_t)host_addr /*dst*/, dev_addr /*src*/, dma_size, FPGA_TO_HOST_MM);
	#endif
	if(res != FPGA_OK)
		return res;
	
	if(remainder)
		res = read_memory_mmio(host_addr+dma_size/8, dev_addr+dma_size, remainder);
	
	if(res != FPGA_OK)
		return res;

	DCP_DEBUG_MEM("DCP DEBUG: host_addr=%lx, dev_addr=%lx, size=%d\n", host_addr, dev_addr, size);
	DCP_DEBUG_MEM("DCP DEBUG: remainder=%d, dma_size=%d, size=%d\n", remainder, dma_size, size);

	DCP_DEBUG_MEM("DCP DEBUG: CcipDevice::read_memory done!\n");
	return FPGA_OK;
}

int CcipDevice::read_memory_mmio_unaligned(void *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_MEM("DCP DEBUG: read_memory_mmio_unaligned %p %lx %ld\n", host_addr, dev_addr, size);
	int res = FPGA_OK;
	
	uint64_t shift = dev_addr % 8;
	
	assert(size+shift <= 8);

	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(afc_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;

	uint64_t dev_aligned_addr = dev_addr - shift;
	
	//read data from device memory
	uint64_t read_tmp;
	res = fpgaReadMMIO64(afc_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+((dev_aligned_addr)&MEM_WINDOW_SPAN_MASK), &read_tmp);
	if(res != FPGA_OK)
		return res;
	//overlay our data
	memcpy(host_addr, ((char *)(&read_tmp))+shift, size);
	
	return FPGA_OK;
}

int CcipDevice::read_memory_mmio(uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_MEM("DCP DEBUG: read_memory_mmio %p %lx %ld\n", host_addr, dev_addr, size);

	int res = FPGA_OK;
	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(afc_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;
	DCP_DEBUG_MEM("DCP DEBUG: set page %08lx\n", cur_mem_page);
	for(size_t i = 0; i < size/8; i++) {
		uint64_t mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		if(mem_page != cur_mem_page) {
			cur_mem_page = mem_page;
			res = fpgaWriteMMIO64(afc_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
			if(res != FPGA_OK)
				return res;
			DCP_DEBUG_MEM("DCP DEBUG: set page %08lx\n", cur_mem_page);
		}
		DCP_DEBUG_MEM("DCP DEBUG: read data %8p %08lx %16p\n", host_addr, dev_addr, host_addr);
		res = fpgaReadMMIO64(afc_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+(dev_addr&MEM_WINDOW_SPAN_MASK), host_addr);
		if(res != FPGA_OK)
			return res;

		host_addr += 1;
		dev_addr += 8;
	}
	
		
	if(size % 8 != 0)
	{
		res = read_memory_mmio_unaligned(host_addr, dev_addr, size%8);
		if(res != FPGA_OK)
			return res;
	}

	DCP_DEBUG_MEM("DCP DEBUG: CcipDevice::read_memory_mmio done!\n");
	return FPGA_OK;
}

int CcipDevice::write_memory(const uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_MEM("DCP DEBUG: write_memory %p %lx %ld\n", host_addr, dev_addr, size);
	int res = FPGA_OK;
	
	//check for alignment
	if(dev_addr % DMA_ALIGNMENT != 0)
	{
		//check for mmio alignment
		uint64_t mmio_shift = dev_addr % 8;
		if(mmio_shift != 0)
		{
			size_t unaligned_size = 8 - mmio_shift;
			if(unaligned_size > size)
				unaligned_size = size;
			
			DCP_DEBUG_MEM("DCP DEBUG: write_memory %ld %ld %ld\n", mmio_shift, unaligned_size, size);
			write_memory_mmio_unaligned(host_addr, dev_addr, unaligned_size);
			
			if(size > unaligned_size)
				res = write_memory((uint64_t *)(((char *)host_addr)+unaligned_size), dev_addr+unaligned_size, size-unaligned_size);
			return res;
		}
		
		//TODO: need to do a shift here
		return write_memory_mmio(host_addr, dev_addr, size);
	}
	
	//check size
	if(size < MINIMUM_DMA_SIZE)
		return write_memory_mmio(host_addr, dev_addr, size);
	
	size_t remainder = (size % DMA_ALIGNMENT);
	size_t dma_size = size - remainder;
	
	//TODO: make switch for MMIO
	#ifdef DISABLE_DMA
	res = write_memory_mmio(host_addr, dev_addr, dma_size);
	#else
	res = fpgaDmaTransferSync(dma_h, dev_addr /*dst*/, (uint64_t)host_addr /*src*/, dma_size, HOST_TO_FPGA_MM);
	#endif
	if(res != FPGA_OK)
		return res;
	
	if(remainder)
		res = write_memory(host_addr+dma_size/8, dev_addr+dma_size, remainder);
	
	if(res != FPGA_OK)
		return res;

	DCP_DEBUG_MEM("DCP DEBUG: host_addr=%lx, dev_addr=%lx, size=%d\n", host_addr, dev_addr, size);
	DCP_DEBUG_MEM("DCP DEBUG: remainder=%d, dma_size=%d, size=%d\n", remainder, dma_size, size);

	DCP_DEBUG_MEM("DCP DEBUG: CcipDevice::write_memory done!\n");
	return FPGA_OK;
}

int CcipDevice::write_memory_mmio_unaligned(const uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_MEM("DCP DEBUG: write_memory_mmio_unaligned %p %lx %ld\n", host_addr, dev_addr, size);
	int res = FPGA_OK;
	
	uint64_t shift = dev_addr % 8;
	
	assert(size+shift <= 8);

	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(afc_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;

	uint64_t dev_aligned_addr = dev_addr - shift;
	
	//read data from device memory
	uint64_t read_tmp;
	res = fpgaReadMMIO64(afc_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+((dev_aligned_addr)&MEM_WINDOW_SPAN_MASK), &read_tmp);
	if(res != FPGA_OK)
		return res;
	//overlay our data
	memcpy(((char *)(&read_tmp))+shift, host_addr, size);
	
	//write back to device
	res = fpgaWriteMMIO64(afc_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+(dev_aligned_addr&MEM_WINDOW_SPAN_MASK), read_tmp);
	if(res != FPGA_OK)
		return res;
	
	return FPGA_OK;
}

int CcipDevice::write_memory_mmio(const uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_MEM("DCP DEBUG: write_memory_mmio %p %lx %ld\n", host_addr, dev_addr, size);
	
	int res = FPGA_OK;
	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(afc_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;
	DCP_DEBUG_MEM("DCP DEBUG: set page %08lx\n", cur_mem_page);
	for(size_t i = 0; i < size/8; i++) {
		uint64_t mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		if(mem_page != cur_mem_page) {
			cur_mem_page = mem_page;
			res = fpgaWriteMMIO64(afc_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
			if(res != FPGA_OK)
				return res;
			DCP_DEBUG_MEM("DCP DEBUG: set page %08lx\n", cur_mem_page);
		}
		DCP_DEBUG_MEM("DCP DEBUG: write data %8p %08lx %016lx\n", host_addr, dev_addr, *host_addr);
		res = fpgaWriteMMIO64(afc_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+(dev_addr&MEM_WINDOW_SPAN_MASK), *host_addr);
		if(res != FPGA_OK)
			return res;

		host_addr += 1;
		dev_addr += 8;
	}
	
	if(size % 8 != 0)
	{
		res = write_memory_mmio_unaligned(host_addr, dev_addr, size%8);
		if(res != FPGA_OK)
			return res;
	}

	DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_write done!\n");
	return FPGA_OK;
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

