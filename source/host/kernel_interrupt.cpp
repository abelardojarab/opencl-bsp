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

#include <poll.h>
#include <stdlib.h>

#include <thread>

#include "kernel_interrupt.h"
#include "ccip_mmd_device.h"

//if ENABLE_OPENCL_KERNEL_INTERRUPTS is set at compile time, interrupts will
//be enabled.  otherwise it will using polling/yield
//#define ENABLE_OPENCL_KERNEL_INTERRUPTS

//ccip interrupt line that is used for kernel
#define MMD_KERNEL_INTERRUPT_LINE_NUM	1

//timeout value for polling function
#define POLL_TIMEOUT_MS	10

KernelInterrupt::KernelInterrupt(
		fpga_handle fpga_handle_arg,
		int mmd_handle
	) :
	m_initialized(false),
	m_thread_running(false),
	m_thread(NULL),
	m_kernel_interrupt_fn(NULL),
	m_kernel_interrupt_user_data(NULL),
	m_fpga_handle(fpga_handle_arg),
	m_mmd_handle(mmd_handle),
	m_event_handle(0)
{
	enable_interrupts();
}

KernelInterrupt::~KernelInterrupt()
{
	disable_interrupts();
}

void KernelInterrupt::disable_interrupts()
{
	//kill the thread
	m_thread_running = false;
	if(m_thread)
	{
		//join with thread until it ends
		m_thread->join();

		delete m_thread;
		m_thread = NULL;
	}

	if(m_event_handle)
	{
		fpga_result res;
		res = fpgaUnregisterEvent(m_fpga_handle, FPGA_EVENT_INTERRUPT, m_event_handle);
		if(res != FPGA_OK)
		{
			printf("error fpgaUnregisterEvent");
		}

		res = fpgaDestroyEventHandle(&m_event_handle);
		if(res != FPGA_OK)
		{
			printf("error fpgaDestroyEventHandle");
		}
	}

	//disable opencl kernel interrupts
	set_interrupt_mask(0x00000000);

	m_initialized = false;
}

void KernelInterrupt::enable_interrupts()
{
#ifdef ENABLE_OPENCL_KERNEL_INTERRUPTS
	m_thread_running = true;
	m_thread = new std::thread(interrupt_polling_thread, this);

	fpga_result res;
	// Create event
	res = fpgaCreateEventHandle(&m_event_handle);
	if(res != FPGA_OK)
	{
		printf("error creating event handle");
		return;
	}

	// Register user interrupt with event handle
	res = fpgaRegisterEvent(m_fpga_handle, FPGA_EVENT_INTERRUPT, m_event_handle, MMD_KERNEL_INTERRUPT_LINE_NUM);
	if(res != FPGA_OK)
	{
		printf("error registering event");
		res = fpgaDestroyEventHandle(&m_event_handle);
		return;
	}

	//enable opencl kernel interrupts
	set_interrupt_mask(0x00000001);

	m_initialized = true;
#else
	m_initialized = true;
#endif
}

void KernelInterrupt::set_interrupt_mask(uint32_t intr_mask)
{
	fpga_result res;
	res = fpgaWriteMMIO32(m_fpga_handle, 0, AOCL_IRQ_MASKING_BASE, intr_mask);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error fpgaWriteMMIO32: %d\n", res);
		return;
	}
}

void KernelInterrupt::interrupt_polling_thread(KernelInterrupt *obj)
{
	struct pollfd pfd;
	int res;

	while(obj && obj->m_thread_running.load())
	{
		// Poll event handle
		pfd.fd = (int)obj->m_event_handle;
		pfd.events = POLLIN;
		res = poll(&pfd, 1, POLL_TIMEOUT_MS);
		if(res < 0) {
			fprintf( stderr, "Poll error errno = %s\n",strerror(errno));
		}
		else if(res == 0) {
			//poll timeout
			DEBUG_PRINT( stderr, "Poll timeout \n");
		} else {
			uint64_t count;
			read(pfd.fd, &count, sizeof(count));
			DEBUG_PRINT("Poll success. Return=%d count=%u\n",res);
			obj->run_kernel_interrupt_fn();
		}
	}
}

bool KernelInterrupt::yield_is_enabled()
{
#ifdef ENABLE_OPENCL_KERNEL_INTERRUPTS
	return false;
#else
	return true;
#endif
}

void KernelInterrupt::yield() {
#ifdef ENABLE_OPENCL_KERNEL_INTERRUPTS
	usleep(0);
#else
	uint32_t irqval = 0;
	fpga_result res;

	res = fpgaReadMMIO32(m_fpga_handle, 0, AOCL_IRQ_POLLING_BASE, &irqval);
	if(res != FPGA_OK) {
		fprintf(stderr, "Error fpgaReadMMIO32: %d\n", res);
		return;
	}

	DEBUG_PRINT("irqval: %u\n", irqval);
	if(irqval) {
		run_kernel_interrupt_fn();
	}
#endif
}

void KernelInterrupt::run_kernel_interrupt_fn()
{
	if(m_kernel_interrupt_fn)
	{
		m_kernel_interrupt_fn(m_mmd_handle, m_kernel_interrupt_user_data);
	}
	else
	{
		fprintf(stderr, "m_kernel_interrupt_fn is NULL.  No interrupt handler set!\n");
	}
}

void KernelInterrupt::set_kernel_interrupt(aocl_mmd_interrupt_handler_fn fn, void* user_data)
{
	m_kernel_interrupt_fn = fn;
	m_kernel_interrupt_user_data = user_data;
}

