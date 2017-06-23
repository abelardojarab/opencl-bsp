#include "ccip_mmd_device.h"
#include "afu_bbb_util.h"

CcipDevice::CcipDevice(int dev_num, int unique_id):
	kernel_interrupt(NULL),
	kernel_interrupt_user_data(NULL),
	event_update(NULL),
	event_update_user_data(NULL),
	initialized(false),
	afc_handle(NULL),
	filter(NULL),
	afc_token(NULL),
	dma_h(NULL),
	msgdma_bbb_base_addr(0)
{

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

	res = fpgaPropertiesSetObjectType(filter, FPGA_AFC);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error setting object type\n");
		return;
	}

	res = fpgaPropertiesSetGUID(filter, guid);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error setting GUID\n");
		return;
	}

	//TODO: Add selection via BDF / device ID
	res = fpgaEnumerate(&filter, 1, &afc_token, 1, &num_matches);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error enumerating AFCs: %d\n", res);
		return;
	}

	if(num_matches < 1) {
		fprintf(stderr, "AFC not found\n");
		res = fpgaDestroyProperties(&filter);
		return;
	}

	res = fpgaOpen(afc_token, &afc_handle, 0);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error opening AFC: %d\n", res);
		return;
	}

	res = fpgaMapMMIO(afc_handle, 0, NULL);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error mapping MMIO space: %d\n", res);
		return;
	}

	/* Reset AFC */
	res = fpgaReset(afc_handle);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error resetting AFC: %d\n", res);
		return;
	}
	AFU_RESET_DELAY();
	
	res = fpgaDmaOpen(afc_handle, &dma_h);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error initializing DMA: %d\n", res);
		return;
	}
	
	//need base address for address span extender
	uint64_t dfh_size = 0;
	bool found_dfh = find_dfh_by_guid(afc_handle, MSGDMA_BBB_GUID, &msgdma_bbb_base_addr, &dfh_size);
	if(!found_dfh || dfh_size != MSGDMA_BBB_SIZE) {
		fprintf(stderr, "Error initializing DMA: %d\n", res);
		return;
	}
	
	initialized = true;
}

CcipDevice::~CcipDevice()
{
	int num_errors = 0;
	
	if(dma_h) {
		if(fpgaDmaClose(dma_h) != FPGA_OK)
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

int CcipDevice::yield() {
	//TODO: determine exactly what the yield() function should be doing
	//the pcie reference example looks different from what the old MMD was doing
	kernel_interrupt(1, kernel_interrupt_user_data);
	return 0;
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

//for DDR through MMIO
#define MEM_WINDOW_CRTL (msgdma_bbb_base_addr+0x200)
#define MEM_WINDOW_MEM (msgdma_bbb_base_addr+0x1000)
#define MEM_WINDOW_SPAN (4*1024)
#define MEM_WINDOW_SPAN_MASK ((long)(MEM_WINDOW_SPAN-1))

#define MINIMUM_DMA_SIZE	256
#define DMA_ALIGNMENT	64

int CcipDevice::read_memory(uint64_t *host_addr, size_t dev_addr, size_t size)
{
	int res;
	
	//check size and alignment
	if(size < MINIMUM_DMA_SIZE || (dev_addr % DMA_ALIGNMENT != 0))
		return read_memory_mmio(host_addr, dev_addr, size);
	
	size_t remainder = (size % DMA_ALIGNMENT);
	size_t dma_size = size - remainder;
	
	//TODO: make switch for MMIO
	//res = read_memory_mmio(host_addr, dev_addr, dma_size);
	res = fpgaDmaTransferSync(dma_h, (uint64_t)host_addr /*dst*/, dev_addr /*src*/, dma_size, FPGA_TO_HOST_MM);
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

int CcipDevice::read_memory_mmio(uint64_t *host_addr, size_t dev_addr, size_t size)
{
	fpga_result res = FPGA_OK;
	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(afc_handle, 0, MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;
	DCP_DEBUG_MEM("DCP DEBUG: set page %08lx\n", cur_mem_page);
	for(size_t i = 0; i < size/8; i++) {
		uint64_t mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		if(mem_page != cur_mem_page) {
			cur_mem_page = mem_page;
			res = fpgaWriteMMIO64(afc_handle, 0, MEM_WINDOW_CRTL, cur_mem_page);
			if(res != FPGA_OK)
				return res;
			DCP_DEBUG_MEM("DCP DEBUG: set page %08lx\n", cur_mem_page);
		}
		DCP_DEBUG_MEM("DCP DEBUG: read data %8p %08lx %16p\n", host_addr, dev_addr, host_addr);
		res = fpgaReadMMIO64(afc_handle, 0, MEM_WINDOW_MEM+(dev_addr&MEM_WINDOW_SPAN_MASK), host_addr);
		if(res != FPGA_OK)
			return res;

		host_addr += 1;
		dev_addr += 8;
	}

	DCP_DEBUG_MEM("DCP DEBUG: CcipDevice::read_memory_mmio done!\n");
	return FPGA_OK;
}

int CcipDevice::write_memory(const uint64_t *host_addr, size_t dev_addr, size_t size)
{
	fpga_result res = FPGA_OK;
	uint64_t cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
	res = fpgaWriteMMIO64(afc_handle, 0, MEM_WINDOW_CRTL, cur_mem_page);
	if(res != FPGA_OK)
		return res;
	DCP_DEBUG_MEM("DCP DEBUG: set page %08lx\n", cur_mem_page);
	for(size_t i = 0; i < size/8; i++) {
		uint64_t mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		if(mem_page != cur_mem_page) {
			cur_mem_page = mem_page;
			res = fpgaWriteMMIO64(afc_handle, 0, MEM_WINDOW_CRTL, cur_mem_page);
			if(res != FPGA_OK)
				return res;
			DCP_DEBUG_MEM("DCP DEBUG: set page %08lx\n", cur_mem_page);
		}
		DCP_DEBUG_MEM("DCP DEBUG: write data %8p %08lx %016lx\n", host_addr, dev_addr, *host_addr);
		res = fpgaWriteMMIO64(afc_handle, 0, MEM_WINDOW_MEM+(dev_addr&MEM_WINDOW_SPAN_MASK), *host_addr);
		if(res != FPGA_OK)
			return res;

		host_addr += 1;
		dev_addr += 8;
	}

	DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_write done!\n");
	return FPGA_OK;
}

#undef MEM_WINDOW_CRTL
#undef MEM_WINDOW_MEM
#undef MEM_WINDOW_SPAN
#undef MEM_WINDOW_SPAN_MASK

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
		res = fpgaWriteMMIO32(afc_handle, 0, mmio_addr, *host_addr32);
		if(res != FPGA_OK)
			return res;
		host_addr32 += 1;
		mmio_addr += 4;
		size -= 4;
	}

	return res;
}

