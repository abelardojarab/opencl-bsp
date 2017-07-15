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
  input	          clock_reset_clk,
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
  input           avmm_r_waitrequest,
  input  [511:0] 	avmm_r_readdata,
  input          	avmm_r_readdatavalid,
  output [4:0]   	avmm_r_burstcount,
  output [63:0]  	avmm_r_address,
  output         	avmm_r_read,
  input           avmm_w_waitrequest,
  output [4:0]   	avmm_w_burstcount,
  output [511:0] 	avmm_w_writedata,
  output [63:0]  	avmm_w_address,
  output         	avmm_w_write,
  output [63:0]  	avmm_w_byteenable
);

//=======================================================
//  kernel_system instantiation
//=======================================================
kernel_system kernel_system_inst (
  .clock_reset_clk(clock_reset_clk),
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
  .avmm_r_waitrequest(avmm_r_waitrequest),
  .avmm_r_readdata(avmm_r_readdata),
  .avmm_r_readdatavalid(avmm_r_readdatavalid),
  .avmm_r_burstcount(avmm_r_burstcount),
  .avmm_r_address(avmm_r_address),
  .avmm_r_read(avmm_r_read),
  .avmm_w_waitrequest(avmm_w_waitrequest),
  .avmm_w_burstcount(avmm_w_burstcount),
  .avmm_w_writedata(avmm_w_writedata),
  .avmm_w_address(avmm_w_address),
  .avmm_w_write(avmm_w_write),
  .avmm_w_byteenable(avmm_w_byteenable),
  .avmm_r_writedata(),
  .avmm_r_write(),
  .avmm_r_byteenable(),
  .avmm_w_readdata(512'b0),
  .avmm_w_readdatavalid(1'b0),
  .avmm_w_read()
);

endmodule