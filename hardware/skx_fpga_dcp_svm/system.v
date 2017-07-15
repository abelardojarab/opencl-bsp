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

//MPF interface
		input  wire         ci0_InitDone,          //          ci0.InitDone
		input  wire         ci0_virtual_access,    //             .virtual_access
		input  wire         ci0_tx_c0_almostfull,  //             .tx_c0_almostfull
		input  wire [27:0]  ci0_rx_c0_header,      //             .rx_c0_header
		input  wire [511:0] ci0_rx_c0_data,        //             .rx_c0_data
		input  wire         ci0_rx_c0_wrvalid,     //             .rx_c0_wrvalid
		input  wire         ci0_rx_c0_rdvalid,     //             .rx_c0_rdvalid
		input  wire         ci0_rx_c0_ugvalid,     //             .rx_c0_ugvalid
		input  wire         ci0_rx_c0_mmiordvalid, //             .rx_c0_mmiordvalid
		input  wire         ci0_rx_c0_mmiowrvalid, //             .rx_c0_mmiowrvalid
		input  wire         ci0_tx_c1_almostfull,  //             .tx_c1_almostfull
		input  wire [27:0]  ci0_rx_c1_header,      //             .rx_c1_header
		input  wire         ci0_rx_c1_wrvalid,     //             .rx_c1_wrvalid
		input  wire         ci0_rx_c1_irvalid,     //             .rx_c1_irvalid
		output wire [98:0]  ci0_tx_c0_header,      //             .tx_c0_header
		output wire         ci0_tx_c0_rdvalid,     //             .tx_c0_rdvalid
		output wire [98:0]  ci0_tx_c1_header,      //             .tx_c1_header
		output wire [511:0] ci0_tx_c1_data,        //             .tx_c1_data
		output wire         ci0_tx_c1_wrvalid,     //             .tx_c1_wrvalid
		output wire         ci0_tx_c1_irvalid,     //             .tx_c1_irvalid
		output wire [8:0]   ci0_tx_c2_header,      //             .tx_c2_header
		output wire         ci0_tx_c2_rdvalid,     //             .tx_c2_rdvalid
		output wire [63:0]  ci0_tx_c2_data,        //             .tx_c2_data
		output wire [63:0]  ci0_tx_c1_byteen,        //             .tx_c2_data
		input  wire         clk_200_clk,           //      clk_200.clk
		input  wire         clk_400_clk,           //      clk_400.clk
		input  wire         global_reset_reset_n,  // global_reset.reset_n
    input wire         kernel_clk,
    input wire          bridge_reset_reset,
    input  wire         opencl_freeze,
	  output wire  nohazards_rd  ,     
  output wire nohazards_wr_full,  
  output wire nohazards_wr_all ,
  
  
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
  output           board_avmm_r_waitrequest,
  output  [511:0] 	board_avmm_r_readdata,
  output          	board_avmm_r_readdatavalid,
  input [4:0]   	board_avmm_r_burstcount,
  input [511:0]	board_avmm_r_writedata,
  input [63:0]  	board_avmm_r_address,
  input        	board_avmm_r_write,
  input         	board_avmm_r_read,
  input [63:0]  	board_avmm_r_byteenable,
  input         	board_avmm_r_debugaccess,
  output          	board_avmm_w_waitrequest,
  output  [511:0] 	board_avmm_w_readdata,
  output          	board_avmm_w_readdatavalid,
  input [4:0]   	board_avmm_w_burstcount,
  input [511:0] 	board_avmm_w_writedata,
  input [63:0]  	board_avmm_w_address,
  input         	board_avmm_w_write,
  input         	board_avmm_w_read,
  input [63:0]  	board_avmm_w_byteenable,
  input         	board_avmm_w_debugaccess
  
  
  
  
  
  
  
  
  
  
  
	);


	
  board board_inst (
    .ci0_InitDone                       (ci0_InitDone),                                    //          ci0.InitDone
    .ci0_virtual_access                 (ci0_virtual_access),                              //             .virtual_access
    .ci0_tx_c0_almostfull               (ci0_tx_c0_almostfull),                            //             .tx_c0_almostfull
    .ci0_rx_c0_header                   (ci0_rx_c0_header),                                //             .rx_c0_header
    .ci0_rx_c0_data                     (ci0_rx_c0_data),                                  //             .rx_c0_data
    .ci0_rx_c0_wrvalid                  (ci0_rx_c0_wrvalid),                               //             .rx_c0_wrvalid
    .ci0_rx_c0_rdvalid                  (ci0_rx_c0_rdvalid),                               //             .rx_c0_rdvalid
    .ci0_rx_c0_ugvalid                  (ci0_rx_c0_ugvalid),                               //             .rx_c0_ugvalid
    .ci0_rx_c0_mmiordvalid              (ci0_rx_c0_mmiordvalid),                           //             .rx_c0_mmiordvalid
    .ci0_rx_c0_mmiowrvalid              (ci0_rx_c0_mmiowrvalid),                           //             .rx_c0_mmiowrvalid
    .ci0_tx_c1_almostfull               (ci0_tx_c1_almostfull),                            //             .tx_c1_almostfull
    .ci0_rx_c1_header                   (ci0_rx_c1_header),                                //             .rx_c1_header
    .ci0_rx_c1_wrvalid                  (ci0_rx_c1_wrvalid),                               //             .rx_c1_wrvalid
    .ci0_rx_c1_irvalid                  (ci0_rx_c1_irvalid),                               //             .rx_c1_irvalid
    .ci0_tx_c0_header                   (ci0_tx_c0_header),                                //             .tx_c0_header
    .ci0_tx_c0_rdvalid                  (ci0_tx_c0_rdvalid),                               //             .tx_c0_rdvalid
    .ci0_tx_c1_header                   (ci0_tx_c1_header),                                //             .tx_c1_header
    .ci0_tx_c1_data                     (ci0_tx_c1_data),                                  //             .tx_c1_data
    .ci0_tx_c1_wrvalid                  (ci0_tx_c1_wrvalid),                               //             .tx_c1_wrvalid
    .ci0_tx_c1_irvalid                  (ci0_tx_c1_irvalid),                               //             .tx_c1_irvalid
    .ci0_tx_c2_header                   (ci0_tx_c2_header),                                //             .tx_c2_header
    .ci0_tx_c2_rdvalid                  (ci0_tx_c2_rdvalid),                               //             .tx_c2_rdvalid
    .ci0_tx_c2_data                     (ci0_tx_c2_data),                                  //             .tx_c2_data
    .ci0_tx_c1_byteen           (ci0_tx_c1_byteen),                                  //             .tx_c2_data
    .clk_400_clk                        (clk_400_clk),                                     //      clk_400.clk
   
    .global_reset_reset_n               (global_reset_reset_n),                            // global_reset.reset_n
    .bridge_reset_reset                 (bridge_reset_reset),
    .kernel_clk_clk                     (board_kernel_clk_clk),                            //   kernel_clk.clk
    //.kernel_clk2x_clk                   (board_kernel_clk2x_clk),                          // kernel_clk2x.clk
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
    .avmm_r_slave_waitrequest           (board_avmm_r_waitrequest),
    .avmm_r_slave_readdata              (board_avmm_r_readdata),
    .avmm_r_slave_readdatavalid         (board_avmm_r_readdatavalid),
    .avmm_r_slave_burstcount            (board_avmm_r_burstcount),
    .avmm_r_slave_writedata             (board_avmm_r_writedata),
    .avmm_r_slave_address               (board_avmm_r_address),
    .avmm_r_slave_write                 (board_avmm_r_write),
    .avmm_r_slave_read                  (board_avmm_r_read),
    .avmm_r_slave_byteenable            (board_avmm_r_byteenable),
    .avmm_r_slave_debugaccess           (board_avmm_r_debugaccess),
    .avmm_w_slave_waitrequest           (board_avmm_w_waitrequest),
    .avmm_w_slave_readdata              (board_avmm_w_readdata),
    .avmm_w_slave_readdatavalid         (board_avmm_w_readdatavalid),
    .avmm_w_slave_burstcount            (board_avmm_w_burstcount),
    .avmm_w_slave_writedata             (board_avmm_w_writedata),
    .avmm_w_slave_address               (board_avmm_w_address),
    .avmm_w_slave_write                 (board_avmm_w_write),
    .avmm_w_slave_read                  (board_avmm_w_read),
    .avmm_w_slave_byteenable            (board_avmm_w_byteenable),
    .avmm_w_slave_debugaccess           (board_avmm_w_debugaccess),
	.ci0_nohazards_rd  (nohazards_rd),   
    .ci0_nohazards_wr_full (nohazards_wr_full),
    .ci0_nohazards_wr_all (nohazards_wr_all),
	.kernel_clk_in_clk(kernel_clk)
	);



endmodule
