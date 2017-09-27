// ***************************************************************************
// Copyright (c) 2017, Intel Corporation
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// * Neither the name of Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// ***************************************************************************

import ccip_if_pkg::*;
import ccip_avmm_pkg::*;

module ccip_avmm_bridge  #(
	parameter MMIO_BYPASS_ADDRESS = 0,
	parameter MMIO_BYPASS_SIZE = 0
	)
	
	(
	// ---------------------------global signals-------------------------------------------------
	input	clk,	  //              in    std_logic;           Core clock. CCI interface is synchronous to this clock.
	input	reset,	  //              in    std_logic;           CCI interface reset. The Accelerator IP must use this Reset. ACTIVE HIGH

	// ---------------------------IF signals between CCI and AFU  --------------------------------
	input	t_if_ccip_Rx    cp2af_sRxPort,
	output	t_if_ccip_Tx	af2cp_sTxPort,

	// ---------------------------IF signals AVMM and requestor  --------------------------------

	output logic		requestor_avmm_waitrequest,
	output logic	[CCIP_AVMM_REQUESTOR_DATA_WIDTH-1:0]	requestor_avmm_readdata,
	output logic		requestor_avmm_readdatavalid,
	input 	[CCIP_AVMM_REQUESTOR_DATA_WIDTH-1:0]	requestor_avmm_writedata,
	input 	[CCIP_AVMM_REQUESTOR_ADDR_WIDTH-1:0]	requestor_avmm_address,
	input 		requestor_avmm_write,
	input 		requestor_avmm_read,
	input 	[CCIP_AVMM_REQUESTOR_BURST_WIDTH-1:0]	requestor_avmm_burstcount,

	// ---------------------------IF signals AVMM and MMIO  --------------------------------

	input		mmio_avmm_waitrequest,
	input	[CCIP_AVMM_MMIO_DATA_WIDTH-1:0]	mmio_avmm_readdata,
	input		mmio_avmm_readdatavalid,
	output logic 	[CCIP_AVMM_MMIO_DATA_WIDTH-1:0]	mmio_avmm_writedata,
	output logic 	[CCIP_AVMM_MMIO_ADDR_WIDTH-1:0]	mmio_avmm_address,
	output logic 		mmio_avmm_write,
	output logic 		mmio_avmm_read,
	output logic 	[(CCIP_AVMM_MMIO_DATA_WIDTH/8)-1:0]	mmio_avmm_byteenable
);
	avmm_ccip_host avmm_ccip_host_inst (
		.clk            (clk),            //   clk.clk
		.reset        (reset),         // reset.reset
		
		.avmm_waitrequest(requestor_avmm_waitrequest),
		.avmm_readdata(requestor_avmm_readdata),
		.avmm_readdatavalid(requestor_avmm_readdatavalid),
		.avmm_writedata(requestor_avmm_writedata),
		.avmm_address(requestor_avmm_address),
		.avmm_write(requestor_avmm_write),
		.avmm_read(requestor_avmm_read),
		.avmm_burstcount(requestor_avmm_burstcount),
		
		.c0TxAlmFull(cp2af_sRxPort.c0TxAlmFull),
		.c1TxAlmFull(cp2af_sRxPort.c1TxAlmFull),
		.c0rx(cp2af_sRxPort.c0),
		//.c1rx(cp2af_sRxPort.c1),	//write response
		.c0tx(af2cp_sTxPort.c0),
		.c1tx(af2cp_sTxPort.c1)
	);
	
	ccip_avmm_mmio #(
		.MMIO_BYPASS_ADDRESS(MMIO_BYPASS_ADDRESS),
		.MMIO_BYPASS_SIZE(MMIO_BYPASS_SIZE)
	)
	ccip_avmm_mmio_inst (
		.avmm_waitrequest(mmio_avmm_waitrequest),
		.avmm_readdata(mmio_avmm_readdata),
		.avmm_readdatavalid(mmio_avmm_readdatavalid),
		.avmm_writedata(mmio_avmm_writedata),
		.avmm_address(mmio_avmm_address),
		.avmm_write(mmio_avmm_write),
		.avmm_read(mmio_avmm_read),
		.avmm_byteenable(mmio_avmm_byteenable),
	
		.clk            (clk),            //   clk.clk
		.reset        (reset),         // reset.reset
		
		.ccip_c0_Rx_port(cp2af_sRxPort.c0),
		.ccip_c2_Tx_port(af2cp_sTxPort.c2)
	);
	
endmodule
