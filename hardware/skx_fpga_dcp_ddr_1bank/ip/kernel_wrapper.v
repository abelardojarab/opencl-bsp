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

// kernel wrapper
// This is the PR boundary ports for kernel
// using kernel wrapper instead of kernel_system, since kernel_system is auto generated
// kernel_system introduces boundary ports that are not used, and in PR, it gets preserved

module kernel_wrapper(
  input	          clock_reset2x_clk,
  input        	  clock_reset_reset_reset_n,
  output          kernel_irq_irq,
  output          kernel_cra_waitrequest,
  output [63:0]   kernel_cra_readdata,
  output         	kernel_cra_readdatavalid,
  input   [0:0]   kernel_cra_burstcount,
  input  [63:0]   kernel_cra_writedata,
  input  [29:0]   kernel_cra_address,
  input           kernel_cra_write,
  input           kernel_cra_read,
  input   [7:0]  	kernel_cra_byteenable,
  input           kernel_cra_debugaccess,
  
	input	[32:0]	acl_internal_snoop_data,
	input		acl_internal_snoop_valid,
	output		acl_internal_snoop_ready,
  
    input		kernel_ddr4a_waitrequest,
	input	[511:0]	kernel_ddr4a_readdata,
	input		kernel_ddr4a_readdatavalid,
	output	[4:0]	kernel_ddr4a_burstcount,
	output	[511:0]	kernel_ddr4a_writedata,
	output	[`KERNEL_DDR_ADDRESS_BITS-1:0]	kernel_ddr4a_address,
	output		kernel_ddr4a_write,
	output		kernel_ddr4a_read,
	output	[63:0]	kernel_ddr4a_byteenable,
	output		kernel_ddr4a_debugaccess,
`ifndef DISABLE_2BANK
	input		kernel_ddr4b_waitrequest,
	input	[511:0]	kernel_ddr4b_readdata,
	input		kernel_ddr4b_readdatavalid,
	output	[4:0]	kernel_ddr4b_burstcount,
	output	[511:0]	kernel_ddr4b_writedata,
	output	[`KERNEL_DDR_ADDRESS_BITS-1:0]	kernel_ddr4b_address,
	output		kernel_ddr4b_write,
	output		kernel_ddr4b_read,
	output	[63:0]	kernel_ddr4b_byteenable,
	output		kernel_ddr4b_debugaccess,
`endif
  input	          clock_reset_clk
);

//=======================================================
//  kernel_system instantiation
//=======================================================
kernel_system kernel_system_inst (
  .clock_reset2x_clk(clock_reset2x_clk),
  .clock_reset_reset_reset_n(clock_reset_reset_reset_n),
  .kernel_irq_irq(kernel_irq_irq),
  .kernel_cra_waitrequest(kernel_cra_waitrequest),
  .kernel_cra_readdata(kernel_cra_readdata),
  .kernel_cra_readdatavalid(kernel_cra_readdatavalid),
  .kernel_cra_burstcount(kernel_cra_burstcount),
  .kernel_cra_writedata(kernel_cra_writedata),
  .kernel_cra_address(kernel_cra_address),
  .kernel_cra_write(kernel_cra_write),
  .kernel_cra_read(kernel_cra_read),
  .kernel_cra_byteenable(kernel_cra_byteenable),
  .kernel_cra_debugaccess(kernel_cra_debugaccess),

  .cc_snoop_clk_clk(clock_reset_clk),
  .cc_snoop_data(acl_internal_snoop_data),
  .cc_snoop_valid(acl_internal_snoop_valid),
  .cc_snoop_ready(acl_internal_snoop_ready),
  
  .kernel_ddr4a_waitrequest(kernel_ddr4a_waitrequest),
  .kernel_ddr4a_readdata(kernel_ddr4a_readdata),
  .kernel_ddr4a_readdatavalid(kernel_ddr4a_readdatavalid),
  .kernel_ddr4a_burstcount(kernel_ddr4a_burstcount),
  .kernel_ddr4a_writedata(kernel_ddr4a_writedata),
  .kernel_ddr4a_address(kernel_ddr4a_address),
  .kernel_ddr4a_write(kernel_ddr4a_write),
  .kernel_ddr4a_read(kernel_ddr4a_read),
  .kernel_ddr4a_byteenable(kernel_ddr4a_byteenable),
  .kernel_ddr4a_debugaccess(),
`ifndef DISABLE_2BANK
  .kernel_ddr4b_waitrequest(kernel_ddr4b_waitrequest),
  .kernel_ddr4b_readdata(kernel_ddr4b_readdata),
  .kernel_ddr4b_readdatavalid(kernel_ddr4b_readdatavalid),
  .kernel_ddr4b_burstcount(kernel_ddr4b_burstcount),
  .kernel_ddr4b_writedata(kernel_ddr4b_writedata),
  .kernel_ddr4b_address(kernel_ddr4b_address),
  .kernel_ddr4b_write(kernel_ddr4b_write),
  .kernel_ddr4b_read(kernel_ddr4b_read),
  .kernel_ddr4b_byteenable(kernel_ddr4b_byteenable),
  .kernel_ddr4b_debugaccess(),
`endif
  .clock_reset_clk(clock_reset_clk)
);

endmodule