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
#include <stdlib.h>
#include <string.h>

#include "mmd_dma.h"
#include "ccip_mmd_device.h"
#include "afu_bbb_util.h"

using namespace intel_opae_mmd;

//enables a separate dma work thread.  otherwise DMA operations will be 
//blocking
#define ENABLE_DMA_WORK_THREAD

//disable dma and only use mmio.  this is very slow.
//#define DISABLE_DMA

//for DDR through MMIO
#define MEM_WINDOW_CRTL 0x200
#define MEM_WINDOW_MEM 0x1000
#define MEM_WINDOW_SPAN (4*1024)
#define MEM_WINDOW_SPAN_MASK ((long)(MEM_WINDOW_SPAN-1))

#define MINIMUM_DMA_SIZE	256
#define DMA_ALIGNMENT	256

#define MSGDMA_BBB_GUID		"d79c094c-7cf9-4cc1-94eb-7d79c7c01ca3"
#define MSGDMA_BBB_SIZE		8192

#ifdef DEBUG_MEM
#define DCP_DEBUG_DMA(...) fprintf(stderr,__VA_ARGS__)
#else
#define DCP_DEBUG_DMA(...)
#endif


mmd_dma::mmd_dma(fpga_handle fpga_handle_arg, int mmd_handle) :
	m_initialized(false),
	m_dma_work_thread(NULL),
	m_dma_op_mutex(),
	m_status_handler_fn(NULL),
	m_status_handler_user_data(NULL),
	m_fpga_handle(fpga_handle_arg),
	m_mmd_handle(mmd_handle),
	dma_h(NULL),
	msgdma_bbb_base_addr(0)
{
	#ifndef DISABLE_DMA
	fpga_result res;
	res = fpgaDmaOpen(m_fpga_handle, &dma_h);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error initializing DMA: %d\n", res);
		return;
	}
	#endif
	
	//need base address for address span extender
	uint64_t dfh_size = 0;
	bool found_dfh = find_dfh_by_guid(m_fpga_handle, MSGDMA_BBB_GUID, &msgdma_bbb_base_addr, &dfh_size);
	if(!found_dfh || dfh_size != MSGDMA_BBB_SIZE) {
		fprintf(stderr, "Error initializing DMA\n");
		return;
	}
	
	#ifdef ENABLE_DMA_WORK_THREAD
	m_dma_work_thread = new dma_work_thread(*this);
	if(!m_dma_work_thread->initialized())
		return;
	#endif
	
	m_initialized = true;
}

mmd_dma::~mmd_dma()
{
	//kill the thread
	if(m_dma_work_thread)
	{
		delete m_dma_work_thread;
		m_dma_work_thread = NULL;
	}
	
	if(dma_h) {
		if(fpgaDmaClose(dma_h) != FPGA_OK)
			fprintf(stderr, "Error closing DMA\n");
	}
	m_initialized = false;
}

void mmd_dma::set_status_handler(aocl_mmd_status_handler_fn fn, void *user_data)
{
	m_status_handler_fn = fn;
	m_status_handler_user_data = user_data;
}

void mmd_dma::event_update_fn(aocl_mmd_op_t op, int status)
{
	m_status_handler_fn(m_mmd_handle, m_status_handler_user_data, op, status);
}

int mmd_dma::do_dma(dma_work_item &item)
{
	//main dma function needs to be thread safe because dma csr operations
	//are not thread safe
	std::lock_guard<std::mutex> lock(m_dma_op_mutex);

	int res = 0;
	assert(item.rd_host_addr != NULL || item.wr_host_addr != NULL);
	if(item.rd_host_addr) {
		res = read_memory(item.rd_host_addr, item.dev_addr, item.size);
	} else {
		assert(item.wr_host_addr);
		res = write_memory(item.wr_host_addr, item.dev_addr, item.size);
	}
	
	if(item.op)
	{
		//TODO: check what 'status' value should really be.  Right now just
		//using 0 as was done in previous CCIP MMD.  Also handle case if op is NULL
		event_update_fn(item.op, 0);
	}
	
	return res;
}

int mmd_dma::enqueue_dma(dma_work_item &item)
{
#ifdef ENABLE_DMA_WORK_THREAD
	return m_dma_work_thread->enqueue_dma(item);
#else
	//if work thread is not enabled, then blocking mode is always used.
	return do_dma(item);
#endif
}

int mmd_dma::read_memory(aocl_mmd_op_t op, uint64_t *host_addr, size_t dev_addr, size_t size)
{
	dma_work_item item;
	item.op = op;
	item.rd_host_addr = host_addr;
	item.wr_host_addr = NULL;
	item.dev_addr = dev_addr;
	item.size = size;
	
	return enqueue_dma(item);
}

int mmd_dma::write_memory(aocl_mmd_op_t op, const uint64_t *host_addr, size_t dev_addr, size_t size)
{
	dma_work_item item;
	item.op = op;
	item.rd_host_addr = NULL;
	item.wr_host_addr = host_addr;
	item.dev_addr = dev_addr;
	item.size = size;

	return enqueue_dma(item);
}

int mmd_dma::read_memory(uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_DMA("DCP DEBUG: read_memory %p %lx %ld\n", host_addr, dev_addr, size);
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

	DCP_DEBUG_DMA("DCP DEBUG: host_addr=%lx, dev_addr=%lx, size=%d\n", host_addr, dev_addr, size);
	DCP_DEBUG_DMA("DCP DEBUG: remainder=%d, dma_size=%d, size=%d\n", remainder, dma_size, size);

	DCP_DEBUG_DMA("DCP DEBUG: mmd_dma::read_memory done!\n");
	return FPGA_OK;
}

int mmd_dma::read_memory_mmio_unaligned(void *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_DMA("DCP DEBUG: read_memory_mmio_unaligned %p %lx %ld\n", host_addr, dev_addr, size);
	int res = FPGA_OK;
	
	uint64_t shift = dev_addr % 8;
	
	assert(size+shift <= 8);

	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(m_fpga_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;

	uint64_t dev_aligned_addr = dev_addr - shift;
	
	//read data from device memory
	uint64_t read_tmp;
	res = fpgaReadMMIO64(m_fpga_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+((dev_aligned_addr)&MEM_WINDOW_SPAN_MASK), &read_tmp);
	if(res != FPGA_OK)
		return res;
	//overlay our data
	memcpy(host_addr, ((char *)(&read_tmp))+shift, size);
	
	return FPGA_OK;
}

int mmd_dma::read_memory_mmio(uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_DMA("DCP DEBUG: read_memory_mmio %p %lx %ld\n", host_addr, dev_addr, size);

	int res = FPGA_OK;
	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(m_fpga_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;
	DCP_DEBUG_DMA("DCP DEBUG: set page %08lx\n", cur_mem_page);
	for(size_t i = 0; i < size/8; i++) {
		uint64_t mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		if(mem_page != cur_mem_page) {
			cur_mem_page = mem_page;
			res = fpgaWriteMMIO64(m_fpga_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
			if(res != FPGA_OK)
				return res;
			DCP_DEBUG_DMA("DCP DEBUG: set page %08lx\n", cur_mem_page);
		}
		DCP_DEBUG_DMA("DCP DEBUG: read data %8p %08lx %16p\n", host_addr, dev_addr, host_addr);
		res = fpgaReadMMIO64(m_fpga_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+(dev_addr&MEM_WINDOW_SPAN_MASK), host_addr);
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

	DCP_DEBUG_DMA("DCP DEBUG: mmd_dma::read_memory_mmio done!\n");
	return FPGA_OK;
}

int mmd_dma::write_memory(const uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_DMA("DCP DEBUG: write_memory %p %lx %ld\n", host_addr, dev_addr, size);
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
			
			DCP_DEBUG_DMA("DCP DEBUG: write_memory %ld %ld %ld\n", mmio_shift, unaligned_size, size);
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

	DCP_DEBUG_DMA("DCP DEBUG: host_addr=%lx, dev_addr=%lx, size=%d\n", host_addr, dev_addr, size);
	DCP_DEBUG_DMA("DCP DEBUG: remainder=%d, dma_size=%d, size=%d\n", remainder, dma_size, size);

	DCP_DEBUG_DMA("DCP DEBUG: mmd_dma::write_memory done!\n");
	return FPGA_OK;
}

int mmd_dma::write_memory_mmio_unaligned(const uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_DMA("DCP DEBUG: write_memory_mmio_unaligned %p %lx %ld\n", host_addr, dev_addr, size);
	int res = FPGA_OK;
	
	uint64_t shift = dev_addr % 8;
	
	assert(size+shift <= 8);

	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(m_fpga_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;

	uint64_t dev_aligned_addr = dev_addr - shift;
	
	//read data from device memory
	uint64_t read_tmp;
	res = fpgaReadMMIO64(m_fpga_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+((dev_aligned_addr)&MEM_WINDOW_SPAN_MASK), &read_tmp);
	if(res != FPGA_OK)
		return res;
	//overlay our data
	memcpy(((char *)(&read_tmp))+shift, host_addr, size);
	
	//write back to device
	res = fpgaWriteMMIO64(m_fpga_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+(dev_aligned_addr&MEM_WINDOW_SPAN_MASK), read_tmp);
	if(res != FPGA_OK)
		return res;
	
	return FPGA_OK;
}

int mmd_dma::write_memory_mmio(const uint64_t *host_addr, size_t dev_addr, size_t size)
{
	DCP_DEBUG_DMA("DCP DEBUG: write_memory_mmio %p %lx %ld\n", host_addr, dev_addr, size);
	
	int res = FPGA_OK;
	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(m_fpga_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;
	DCP_DEBUG_DMA("DCP DEBUG: set page %08lx\n", cur_mem_page);
	for(size_t i = 0; i < size/8; i++) {
		uint64_t mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		if(mem_page != cur_mem_page) {
			cur_mem_page = mem_page;
			res = fpgaWriteMMIO64(m_fpga_handle, 0, msgdma_bbb_base_addr+MEM_WINDOW_CRTL, cur_mem_page);
			if(res != FPGA_OK)
				return res;
			DCP_DEBUG_DMA("DCP DEBUG: set page %08lx\n", cur_mem_page);
		}
		DCP_DEBUG_DMA("DCP DEBUG: write data %8p %08lx %016lx\n", host_addr, dev_addr, *host_addr);
		res = fpgaWriteMMIO64(m_fpga_handle, 0, (msgdma_bbb_base_addr+MEM_WINDOW_MEM)+(dev_addr&MEM_WINDOW_SPAN_MASK), *host_addr);
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

	DCP_DEBUG_DMA("DCP DEBUG: aocl_mmd_write done!\n");
	return FPGA_OK;
}

