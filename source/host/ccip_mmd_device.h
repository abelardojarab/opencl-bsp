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

#ifndef _CCIP_MMD_DEVICE_H
#define _CCIP_MMD_DEVICE_H

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>

#include <uuid/uuid.h>
#include <opae/fpga.h>

#include "pkg_editor.h"
#include "aocl_mmd.h"
#include "fpga_dma.h"

// Tune delay for simulation or HW. Eventually delay
// should be removed for HW, may still be needed for ASE simulation
#ifdef SIM
#define DELAY_MULTIPLIER 100
#else
#define DELAY_MULTIPLIER 1
#endif

// Delay settings
// TODO: Figure out why these delays are needed and
// have requirement removed (at least for HW)
#define MMIO_DELAY()
#define YIELD_DELAY()		usleep(1 * DELAY_MULTIPLIER)
#define OPENCL_SW_RESET_DELAY()	usleep(5000 * DELAY_MULTIPLIER)
#define AFU_RESET_DELAY()	usleep(20000 * DELAY_MULTIPLIER)

#define KERNEL_SW_RESET_BASE (AOCL_MMD_KERNEL+0x30)

//AFU IDs:
#define MCP_OPENCL_AFU_ID "C000C966-0D82-4272-9AEF-FE5F84570612"
#define DCP_OPENCL_SVM_AFU_ID "3A00972E-7AAC-41DE-BBD1-3901124E8CDA"
#define DCP_OPENCL_DDR_AFU_ID "18B79FFA-2EE5-4AA0-96EF-4230DAFACB5F"
#define MSGDMA_BBB_GUID		"d79c094c-7cf9-4cc1-94eb-7d79c7c01ca3"
#define MSGDMA_BBB_SIZE		8192

//debugging
#ifdef DEBUG
#define DEBUG_PRINT(...) fprintf(stderr,__VA_ARGS__)
#else
#define DEBUG_PRINT(...)
#endif

#ifdef DEBUG_MEM
#define DCP_DEBUG_MEM(...) fprintf(stderr,__VA_ARGS__)
#else
#define DCP_DEBUG_MEM(...)
#endif

#ifdef SIM
//TODO: put sim specific stuff here
#endif

enum {
	AOCL_IRQ_POLLING_BASE = 0x0100,	//CSR to polling interrupt status
	AOCL_IRQ_MASKING_BASE = 0x0108, //CSR to set/unset interrupt mask
	AOCL_MMD_KERNEL = 0x4000,	/* Control interface into kernel interface */
	AOCL_MMD_MEMORY = 0x100000	/* Data interface to device memory */
};

class CcipDevice final
{
	public:
	CcipDevice();
	~CcipDevice();

	bool is_initialized() { return initialized; }
	fpga_handle get_handle() { return afc_handle; }

	void set_kernel_interrupt(aocl_mmd_interrupt_handler_fn fn, void* user_data);
	void set_status_handler(aocl_mmd_status_handler_fn fn, void* user_data);
	int yield();
	void event_update_fn(aocl_mmd_op_t op, int status);

	int read_block(aocl_mmd_op_t op,
			int mmd_interface,
			void *host_addr,
			size_t dev_addr,
			size_t size);

	int write_block(aocl_mmd_op_t op,
			int mmd_interface,
			const void *host_addr,
			size_t dev_addr,
			size_t size);

	private:
	aocl_mmd_interrupt_handler_fn kernel_interrupt;
	void *kernel_interrupt_user_data;
	aocl_mmd_status_handler_fn event_update;
	void *event_update_user_data;

	bool initialized;
	bool mmio_is_mapped;
	fpga_handle       afc_handle;
	fpga_properties   filter;
	fpga_token        afc_token;
	fpga_dma_handle   dma_h;
	uint64_t          msgdma_bbb_base_addr;

	// Helper functions
	int read_memory(uint64_t *host_addr, size_t dev_addr, size_t size);
	int read_memory_mmio(uint64_t *host_addr, size_t dev_addr, size_t size);
	int write_memory(const uint64_t *host_addr, size_t dev_addr, size_t size);
	int write_memory_mmio(const uint64_t *host_addr, size_t dev_addr, size_t size);
	int write_memory_mmio_unaligned(const uint64_t *host_addr, size_t dev_addr, size_t size);
	int read_memory_mmio_unaligned(void *host_addr, size_t dev_addr, size_t size);
	int read_mmio(void *host_addr, size_t dev_addr, size_t size);
	int write_mmio(const void *host_addr, size_t dev_addr, size_t size);
};

#endif // _CCIP_MMD_DEVICE_H
