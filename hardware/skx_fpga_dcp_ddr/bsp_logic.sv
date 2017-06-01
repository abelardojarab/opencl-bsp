// ***************************************************************************
//
//        Copyright (C) 2008-2015 Intel Corporation All Rights Reserved.
//
// Engineer :           Pratik Marolia
// Creation Date :	20-05-2015
// Last Modified :	Wed 20 May 2015 03:03:09 PM PDT
// Module Name :	ccip_std_afu
// Project :        ccip afu top (work in progress)
// Description :    This module instantiates CCI-P compliant AFU

// ***************************************************************************

`include "cci_mpf_if.vh"

module bsp_logic(
  // CCI-P Clocks and Resets
  input           logic             pClk,              // 400MHz - CCI-P clock domain. Primary interface clock
  input           logic             pClkDiv2,          // 200MHz - CCI-P clock domain.
  input           logic             pClkDiv4,          // 100MHz - CCI-P clock domain.
  input           logic             uClk_usr,          // User clock domain. Refer to clock programming guide  ** Currently provides fixed 300MHz clock **
  input           logic             uClk_usrDiv2,      // User clock domain. Half the programmed frequency  ** Currently provides fixed 150MHz clock **
  input           logic             pck_cp2af_softReset,      // CCI-P ACTIVE HIGH Soft Reset

  // Interface structures
  input           t_if_ccip_Rx      pck_cp2af_sRx,        // CCI-P Rx Port
  output          t_if_ccip_Tx      pck_af2cp_sTx,        // CCI-P Tx Port

  // kernel interface

  // kernel interface
  
    //////// board ports //////////
  output  logic      		board_kernel_reset_reset_n,
  input logic    	board_kernel_irq_irq,
  input logic          board_kernel_cra_waitrequest,
  input logic [63:0]		board_kernel_cra_readdata,
  input logic         	board_kernel_cra_readdatavalid,
  output logic     board_kernel_cra_burstcount,
  output logic  [63:0]   board_kernel_cra_writedata,
  output logic  [29:0]   board_kernel_cra_address,
  output logic         	board_kernel_cra_write,
  output logic         	board_kernel_cra_read,
  output logic   [7:0]  	board_kernel_cra_byteenable,
  output logic         	board_kernel_cra_debugaccess,

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
	input		kernel_ddr4b_debugaccess,
	
  input kernel_clk
);

	wire	[560:0]	avst_host_cmd_data;
	wire		avst_host_cmd_valid;
	wire		avst_host_cmd_ready;
	wire	[511:0]	avst_host_rsp_data;
	wire		avst_host_rsp_valid;
	wire		avst_host_rsp_ready;
	wire	[83:0]	avst_mmio_cmd_data;
	wire		avst_mmio_cmd_valid;
	wire		avst_mmio_cmd_ready;
	wire	[63:0]	avst_mmio_rsp_data;
	wire		avst_mmio_rsp_valid;
	wire		avst_mmio_rsp_ready;

    system u0 (
		.global_reset_reset_n (~pck_cp2af_softReset ), //  global_reset.reset_n
		.clk_400_clk           (pClk ),
		.bridge_reset_reset(pck_cp2af_softReset ),
		.clk_200_clk           (pClkDiv4 ),
		
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

		
		.board_kernel_clk_clk       	(board_kernel_clk_clk       	),
		.board_kernel_clk2x_clk     	(board_kernel_clk2x_clk     	),
		.board_kernel_reset_reset_n 	(board_kernel_reset_reset_n 	),
		.board_kernel_irq_irq       	(board_kernel_irq_irq       	),
		.board_kernel_cra_waitrequest   (board_kernel_cra_waitrequest),
		.board_kernel_cra_readdata      (board_kernel_cra_readdata),
		.board_kernel_cra_readdatavalid (board_kernel_cra_readdatavalid),
		.board_kernel_cra_burstcount    (board_kernel_cra_burstcount),
		.board_kernel_cra_writedata     (board_kernel_cra_writedata),
		.board_kernel_cra_address       (board_kernel_cra_address),
		.board_kernel_cra_write         (board_kernel_cra_write),
		.board_kernel_cra_read          (board_kernel_cra_read),
		.board_kernel_cra_byteenable    (board_kernel_cra_byteenable),
		.board_kernel_cra_debugaccess   (board_kernel_cra_debugaccess),
		
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
		
		.kernel_clk(kernel_clk)
    );
    
    	avmm_ccip_host #(
		.AVMM_ADDR_WIDTH(48), 
		.AVMM_DATA_WIDTH(512))
	avmm_ccip_host_inst (
		.clk            (pClk),            //   clk.clk
		.reset        (pck_cp2af_softReset),         // reset.reset
		
		.avst_rd_rsp_data(avst_host_rsp_data),
		.avst_rd_rsp_valid(avst_host_rsp_valid),
		.avst_rd_rsp_ready(avst_host_rsp_ready), 
		
		.avst_avcmd_data(avst_host_cmd_data),
		.avst_avcmd_valid(avst_host_cmd_valid),
		.avst_avcmd_ready(avst_host_cmd_ready), 
		
		.c0TxAlmFull(pck_cp2af_sRx.c0TxAlmFull),
		.c1TxAlmFull(pck_cp2af_sRx.c1TxAlmFull),
		.c0rx(pck_cp2af_sRx.c0),
		//.c1rx(pck_cp2af_sRx.c1),
		.c0tx(pck_af2cp_sTx.c0),
		.c1tx(pck_af2cp_sTx.c1)
	);
	
	localparam AVMM_ADDR_WIDTH = 18;
	localparam AVMM_DATA_WIDTH = 64;
	localparam AVMM_BYTE_ENABLE_WIDTH=(AVMM_DATA_WIDTH/8);
	
	ccip_avmm_mmio #(AVMM_ADDR_WIDTH, AVMM_DATA_WIDTH)
	ccip_avmm_mmio_inst (
		.in_data (avst_mmio_cmd_data),
		.in_valid(avst_mmio_cmd_valid),
		.in_ready(avst_mmio_cmd_ready),
				 
		.out_data(avst_mmio_rsp_data),
		.out_valid(avst_mmio_rsp_valid),
		.out_ready(avst_mmio_rsp_ready),

		.clk            (pClk),            //   clk.clk
		.SoftReset        (pck_cp2af_softReset),         // reset.reset
		
		.ccip_c0_Rx_port(pck_cp2af_sRx.c0),
		.ccip_c2_Tx_port(pck_af2cp_sTx.c2)
	);


endmodule         
