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

// system.v

// Top level module of OpenCL for MCP

`timescale 1 ps / 1 ps
module system (

	output	[560:0]	avst_host_cmd_data,
	output		avst_host_cmd_valid,
	input		avst_host_cmd_ready,
	input	[511:0]	avst_host_rsp_data,
	input		avst_host_rsp_valid,
	output		avst_host_rsp_ready,
	input	[83:0]	avst_mmio_cmd_data,
	input		avst_mmio_cmd_valid,
	output		avst_mmio_cmd_ready,
	output	[63:0]	avst_mmio_rsp_data,
	output		avst_mmio_rsp_valid,
	input		avst_mmio_rsp_ready,
	
		input  wire         clk_200_clk,           //      clk_200.clk
		input  wire         clk_400_clk,           //      clk_400.clk
		input  wire         global_reset_reset_n,  // global_reset.reset_n
    input wire         kernel_clk,
    input wire          bridge_reset_reset,
  
  // kernel interface
  
    //////// board ports //////////
  output	          board_kernel_clk_clk,
  output	          board_kernel_clk2x_clk,
  output        		board_kernel_reset_reset_n,
  input [0:0]   	board_kernel_irq_irq,
  input          board_kernel_cra_waitrequest,
  input [63:0]		board_kernel_cra_readdata,
  input         	board_kernel_cra_readdatavalid,
  output   [0:0]   board_kernel_cra_burstcount,
  output  [63:0]   board_kernel_cra_writedata,
  output  [29:0]   board_kernel_cra_address,
  output         	board_kernel_cra_write,
  output         	board_kernel_cra_read,
  output   [7:0]  	board_kernel_cra_byteenable,
  output         	board_kernel_cra_debugaccess,
  
  	output	[32:0]	acl_internal_snoop_data,
	output		acl_internal_snoop_valid,
	input		acl_internal_snoop_ready,
  
  	input		ddr_clk_clk,
	
	input		emif_ddr4a_waitrequest,
	input	[511:0]	emif_ddr4a_readdata,
	input		emif_ddr4a_readdatavalid,
	output	[6:0]	emif_ddr4a_burstcount,
	output	[511:0]	emif_ddr4a_writedata,
	output	[31:0]	emif_ddr4a_address,
	output		emif_ddr4a_write,
	output		emif_ddr4a_read,
	output	[63:0]	emif_ddr4a_byteenable,
	output		emif_ddr4a_debugaccess,
	
	input		emif_ddr4b_waitrequest,
	input	[511:0]	emif_ddr4b_readdata,
	input		emif_ddr4b_readdatavalid,
	output	[6:0]	emif_ddr4b_burstcount,
	output	[511:0]	emif_ddr4b_writedata,
	output	[31:0]	emif_ddr4b_address,
	output		emif_ddr4b_write,
	output		emif_ddr4b_read,
	output	[63:0]	emif_ddr4b_byteenable,
	output		emif_ddr4b_debugaccess,
	
	output		kernel_ddr4a_waitrequest,
	output	[511:0]	kernel_ddr4a_readdata,
	output		kernel_ddr4a_readdatavalid,
	input	[4:0]	kernel_ddr4a_burstcount,
	input	[511:0]	kernel_ddr4a_writedata,
	input	[31:0]	kernel_ddr4a_address,
	input		kernel_ddr4a_write,
	input		kernel_ddr4a_read,
	input	[63:0]	kernel_ddr4a_byteenable,
	input		kernel_ddr4a_debugaccess,
	
	output		kernel_ddr4b_waitrequest,
	output	[511:0]	kernel_ddr4b_readdata,
	output		kernel_ddr4b_readdatavalid,
	input	[4:0]	kernel_ddr4b_burstcount,
	input	[511:0]	kernel_ddr4b_writedata,
	input	[31:0]	kernel_ddr4b_address,
	input		kernel_ddr4b_write,
	input		kernel_ddr4b_read,
	input	[63:0]	kernel_ddr4b_byteenable,
	input		kernel_ddr4b_debugaccess
  
	);


	
  board board_inst (
    .clk_400_clk                        (clk_400_clk),                                     //      clk_400.clk
   
    .global_reset_reset_n               (global_reset_reset_n),                            // global_reset.reset_n
    .bridge_reset_reset                 (bridge_reset_reset),
    .kernel_clk_clk                     (board_kernel_clk_clk),                            //   kernel_clk.clk
    .kernel_cra_waitrequest             (board_kernel_cra_waitrequest),                    //   kernel_cra.waitrequest
    .kernel_cra_readdata                (board_kernel_cra_readdata),                       //             .readdata
    .kernel_cra_readdatavalid           (board_kernel_cra_readdatavalid),                  //             .readdatavalid
    .kernel_cra_burstcount              (board_kernel_cra_burstcount),                     //             .burstcount
    .kernel_cra_writedata               (board_kernel_cra_writedata),                      //             .writedata
    .kernel_cra_address                 (board_kernel_cra_address),                        //             .address
    .kernel_cra_write                   (board_kernel_cra_write),                          //             .write
    .kernel_cra_read                    (board_kernel_cra_read),                           //             .read
    .kernel_cra_byteenable              (board_kernel_cra_byteenable),                     //             .byteenable
    .kernel_cra_debugaccess             (board_kernel_cra_debugaccess),                    //             .debugaccess
    .kernel_irq_irq                     (board_kernel_irq_irq),                            //   kernel_irq.irq
    .kernel_reset_reset_n               (board_kernel_reset_reset_n),                        // kernel_reset.reset_n
    .psl_clk_clk                        (clk_200_clk),                                     //      psl_clk.clk
    
.acl_internal_snoop_data(acl_internal_snoop_data),
.acl_internal_snoop_valid(acl_internal_snoop_valid),
.acl_internal_snoop_ready(acl_internal_snoop_ready),
    
.ddr_clk_clk(ddr_clk_clk),

.emif_ddr4a_waitrequest(emif_ddr4a_waitrequest),
.emif_ddr4a_readdata(emif_ddr4a_readdata),
.emif_ddr4a_readdatavalid(emif_ddr4a_readdatavalid),
.emif_ddr4a_burstcount(emif_ddr4a_burstcount),
.emif_ddr4a_writedata(emif_ddr4a_writedata),
.emif_ddr4a_address(emif_ddr4a_address),
.emif_ddr4a_write(emif_ddr4a_write),
.emif_ddr4a_read(emif_ddr4a_read),
.emif_ddr4a_byteenable(emif_ddr4a_byteenable),
.emif_ddr4a_debugaccess(emif_ddr4a_debugaccess),

.emif_ddr4b_waitrequest(emif_ddr4b_waitrequest),
.emif_ddr4b_readdata(emif_ddr4b_readdata),
.emif_ddr4b_readdatavalid(emif_ddr4b_readdatavalid),
.emif_ddr4b_burstcount(emif_ddr4b_burstcount),
.emif_ddr4b_writedata(emif_ddr4b_writedata),
.emif_ddr4b_address(emif_ddr4b_address),
.emif_ddr4b_write(emif_ddr4b_write),
.emif_ddr4b_read(emif_ddr4b_read),
.emif_ddr4b_byteenable(emif_ddr4b_byteenable),
.emif_ddr4b_debugaccess(emif_ddr4b_debugaccess),

.kernel_ddr4a_waitrequest(kernel_ddr4a_waitrequest),
.kernel_ddr4a_readdata(kernel_ddr4a_readdata),
.kernel_ddr4a_readdatavalid(kernel_ddr4a_readdatavalid),
.kernel_ddr4a_burstcount(kernel_ddr4a_burstcount),
.kernel_ddr4a_writedata(kernel_ddr4a_writedata),
.kernel_ddr4a_address(kernel_ddr4a_address),
.kernel_ddr4a_write(kernel_ddr4a_write),
.kernel_ddr4a_read(kernel_ddr4a_read),
.kernel_ddr4a_byteenable(kernel_ddr4a_byteenable),
.kernel_ddr4a_debugaccess(kernel_ddr4a_debugaccess),

.kernel_ddr4b_waitrequest(kernel_ddr4b_waitrequest),
.kernel_ddr4b_readdata(kernel_ddr4b_readdata),
.kernel_ddr4b_readdatavalid(kernel_ddr4b_readdatavalid),
.kernel_ddr4b_burstcount(kernel_ddr4b_burstcount),
.kernel_ddr4b_writedata(kernel_ddr4b_writedata),
.kernel_ddr4b_address(kernel_ddr4b_address),
.kernel_ddr4b_write(kernel_ddr4b_write),
.kernel_ddr4b_read(kernel_ddr4b_read),
.kernel_ddr4b_byteenable(kernel_ddr4b_byteenable),
.kernel_ddr4b_debugaccess(kernel_ddr4b_debugaccess),

.avst_host_cmd_data         (avst_host_cmd_data ),         //      avst_host_cmd.data
.avst_host_cmd_valid        (avst_host_cmd_valid),        //                   .valid
.avst_host_cmd_ready        (avst_host_cmd_ready),        //                   .ready
.avst_host_rsp_data         (avst_host_rsp_data ),         //      avst_host_rsp.data
.avst_host_rsp_valid        (avst_host_rsp_valid),        //                   .valid
.avst_host_rsp_ready        (avst_host_rsp_ready),        //                   .ready
.avst_mmio_cmd_data         (avst_mmio_cmd_data ),         //      avst_mmio_cmd.data
.avst_mmio_cmd_valid        (avst_mmio_cmd_valid),        //                   .valid
.avst_mmio_cmd_ready        (avst_mmio_cmd_ready),        //                   .ready
.avst_mmio_rsp_data         (avst_mmio_rsp_data ),         //      avst_mmio_rsp.data
.avst_mmio_rsp_valid        (avst_mmio_rsp_valid),        //                   .valid
.avst_mmio_rsp_ready        (avst_mmio_rsp_ready),        //                   .ready

	.kernel_clk_in_clk(kernel_clk)
	);



endmodule
