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

#ifndef _MMD_DMA_H
#define _MMD_DMA_H

#include <opae/fpga.h>

#include <thread>
#include <atomic>

#include "fpga_dma.h"
#include "aocl_mmd.h"

namespace intel_opae_mmd {
	
class mmd_dma final
{
public:
	mmd_dma(fpga_handle fpga_handle_arg, int mmd_handle);
	~mmd_dma();

	bool initialized() { return m_initialized; }

	//void set_kernel_interrupt(aocl_mmd_interrupt_handler_fn fn, void* user_data);
	int read_memory(aocl_mmd_op_t op, uint64_t *host_addr, size_t dev_addr, size_t size);
	int write_memory(aocl_mmd_op_t op, const uint64_t *host_addr, size_t dev_addr, size_t size);
	
	void set_status_handler(aocl_mmd_status_handler_fn fn, void *user_data);
	
private:
	// Helper functions
	int read_memory(uint64_t *host_addr, size_t dev_addr, size_t size);
	int write_memory(const uint64_t *host_addr, size_t dev_addr, size_t size);
	int read_memory_mmio(uint64_t *host_addr, size_t dev_addr, size_t size);
	int write_memory_mmio(const uint64_t *host_addr, size_t dev_addr, size_t size);
	int write_memory_mmio_unaligned(const uint64_t *host_addr, size_t dev_addr, size_t size);
	int read_memory_mmio_unaligned(void *host_addr, size_t dev_addr, size_t size);
	
	void event_update_fn(aocl_mmd_op_t op, int status);
	
	//void run_kernel_interrupt_fn();
	//static void interrupt_polling_thread(KernelInterrupt &obj);

	bool m_initialized;
	//eventfd_wrapper *m_eventfd_wrapper;

	//std::thread *m_thread;

	aocl_mmd_status_handler_fn m_status_handler_fn;
	void *m_status_handler_user_data;

	fpga_handle m_fpga_handle;
	int m_mmd_handle;
	
	fpga_dma_handle   dma_h;
	uint64_t          msgdma_bbb_base_addr;

	//not used and not implemented
	mmd_dma (mmd_dma& other);
	mmd_dma& operator= (const mmd_dma& other);
}; // class mmd_dma

}; // namespace intel_opae_mmd

#endif // _MMD_DMA_H

