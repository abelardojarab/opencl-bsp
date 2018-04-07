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

#include <string>

#include <uuid/uuid.h>
#include <opae/fpga.h>

#include "pkg_editor.h"
#include "aocl_mmd.h"
#include "mmd_dma.h"
#include "kernel_interrupt.h"

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

#define BSP_NAME "pac_a10_"

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

enum {
	AOCL_IRQ_POLLING_BASE = 0x0100,	//CSR to polling interrupt status
	AOCL_IRQ_MASKING_BASE = 0x0108, //CSR to set/unset interrupt mask
	AOCL_MMD_KERNEL = 0x4000,	/* Control interface into kernel interface */
	AOCL_MMD_MEMORY = 0x100000	/* Data interface to device memory */
};

enum AfuStatu {
   CCIP_MMD_INVALID_ID = 0,
   CCIP_MMD_BSP,
   CCIP_MMD_AFU
};

class CcipDevice final
{
	public:
	CcipDevice(uint64_t);
   CcipDevice(const CcipDevice&) =delete;
   CcipDevice& operator=(const CcipDevice&) =delete;
	~CcipDevice();

   static std::string get_board_name(std::string prefix, uint64_t obj_id);
   static uint64_t parse_board_name(const char *board_name);

   int get_mmd_handle()         { return mmd_handle; }
   uint64_t get_fpga_obj_id()   { return fpga_obj_id; }
   std::string get_dev_name()   { return mmd_dev_name; }
   std::string get_bdf();
   float get_temperature();

   int program_bitstream(uint8_t *data, size_t data_size);
   bool initialize_bsp();
	void set_kernel_interrupt(aocl_mmd_interrupt_handler_fn fn, void* user_data);
	void set_status_handler(aocl_mmd_status_handler_fn fn, void* user_data);
	int yield();
	void event_update_fn(aocl_mmd_op_t op, int status);
   bool bsp_loaded();

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

	int copy_block(aocl_mmd_op_t op,
		int mmd_interface,
		size_t src_offset, size_t dst_offset,
		size_t size);

	private:
   static int next_mmd_handle;

   int mmd_handle;
   uint64_t fpga_obj_id;
   std::string mmd_dev_name;
   intel_opae_mmd::KernelInterrupt *kernel_interrupt_thread;
	aocl_mmd_status_handler_fn event_update;
	void *event_update_user_data;

   // HACK: use the sysfs path to read temperature value
   // this should be replaced with OPAE call once that is
   // available
   std::string fme_sysfs_temp_path;
   bool fme_sysfs_temp_initialized;
   void initialize_fme_sysfs();

   uint8_t bus;
   uint8_t device;
   uint8_t function;

   bool afu_initialized;
	bool bsp_initialized;
	bool mmio_is_mapped;

	fpga_handle       afc_handle;
	fpga_properties   filter;
	fpga_token        afc_token;
	intel_opae_mmd::mmd_dma *dma_h;

	char *mmd_copy_buffer;

	// Helper functions
	fpga_result read_mmio(void *host_addr, size_t dev_addr, size_t size);
	fpga_result write_mmio(const void *host_addr, size_t dev_addr, size_t size);
};

#endif // _CCIP_MMD_DEVICE_H
