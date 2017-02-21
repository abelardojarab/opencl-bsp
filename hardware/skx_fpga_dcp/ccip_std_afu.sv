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

module ccip_std_afu(
  // CCI-P Clocks and Resets
  input           logic             pClk,              // 400MHz - CCI-P clock domain. Primary interface clock
  input           logic             pClkDiv2,          // 200MHz - CCI-P clock domain.
  input           logic             pClkDiv4,          // 100MHz - CCI-P clock domain.
  input           logic             uClk_usr,          // User clock domain. Refer to clock programming guide  ** Currently provides fixed 300MHz clock **
  input           logic             uClk_usrDiv2,      // User clock domain. Half the programmed frequency  ** Currently provides fixed 150MHz clock **
  input           logic             pck_cp2af_softReset,      // CCI-P ACTIVE HIGH Soft Reset
  input           logic [1:0]       pck_cp2af_pwrState,       // CCI-P AFU Power State
  input           logic             pck_cp2af_error,          // CCI-P Protocol Error Detected

  // Interface structures
  input           t_if_ccip_Rx      pck_cp2af_sRx,        // CCI-P Rx Port
  output          t_if_ccip_Tx      pck_af2cp_sTx        // CCI-P Tx Port

 
);

	wire          board_kernel_cra_waitrequest;                    // board:kernel_cra_waitrequest -> board:kernel_cra_waitrequest
	wire   [63:0] board_kernel_cra_readdata;                       // board:kernel_cra_readdata -> board:kernel_cra_readdata
	wire          board_kernel_cra_debugaccess;                    // board:kernel_cra_debugaccess -> board:kernel_cra_debugaccess
	wire   [29:0] board_kernel_cra_address;                        // board:kernel_cra_address -> board:kernel_cra_address
	wire          board_kernel_cra_read;                           // board:kernel_cra_read -> board:kernel_cra_read
	wire    [7:0] board_kernel_cra_byteenable;                     // board:kernel_cra_byteenable -> board:kernel_cra_byteenable
	wire          board_kernel_cra_readdatavalid;                  // board:kernel_cra_readdatavalid -> board:kernel_cra_readdatavalid
	wire   [63:0] board_kernel_cra_writedata;                      // board:kernel_cra_writedata -> board:kernel_cra_writedata
	wire          board_kernel_cra_write;                          // board:kernel_cra_write -> board:kernel_cra_write
	wire    [0:0] board_kernel_cra_burstcount;                     // board:kernel_cra_burstcount -> board:kernel_cra_burstcount
	wire          board_kernel_clk_clk;                            // board:kernel_clk_clk -> [irq_mapper:clk, board:clock_reset_clk, mm_interconnect_0:board_kernel_clk_clk, mm_interconnect_1:board_kernel_clk_clk, mm_interconnect_2:board_kernel_clk_clk, rr_arb:clk, rst_controller:clk]
	wire          board_kernel_clk2x_clk;                          // board:kernel_clk2x_clk -> board:clock_reset2x_clk
	wire          board_kernel_reset_reset_n;                        // board:kernel_reset_reset_n -> [board:clock_reset_reset_reset_n, mm_interconnect_0:rr_arb_reset_reset_bridge_in_reset_reset, mm_interconnect_1:board_clock_reset_reset_reset_bridge_in_reset_reset, mm_interconnect_2:board_clock_reset_reset_reset_bridge_in_reset_reset, rr_arb:reset]
	wire          board_avmm_r_waitrequest;                // mm_interconnect_1:board_avmm_r_waitrequest -> board:avmm_r_waitrequest
	wire  [511:0] board_avmm_r_readdata;                   // mm_interconnect_1:board_avmm_r_readdata -> board:avmm_r_readdata
	wire          board_avmm_r_debugaccess;                // board:avmm_r_debugaccess -> mm_interconnect_1:board_avmm_r_debugaccess
	wire   [63:0] board_avmm_r_address;                    // board:avmm_r_address -> mm_interconnect_1:board_avmm_r_address
	wire          board_avmm_r_read;                       // board:avmm_r_read -> mm_interconnect_1:board_avmm_r_read
	wire   [63:0] board_avmm_r_byteenable;                 // board:avmm_r_byteenable -> mm_interconnect_1:board_avmm_r_byteenable
	wire          board_avmm_r_readdatavalid;              // mm_interconnect_1:board_avmm_r_readdatavalid -> board:avmm_r_readdatavalid
	wire  [511:0] board_avmm_r_writedata;                  // board:avmm_r_writedata -> mm_interconnect_1:board_avmm_r_writedata
	wire          board_avmm_r_write;                      // board:avmm_r_write -> mm_interconnect_1:board_avmm_r_write
	wire    [4:0] board_avmm_r_burstcount;                 // board:avmm_r_burstcount -> mm_interconnect_1:board_avmm_r_burstcount
	wire          board_avmm_w_waitrequest;                // mm_interconnect_2:board_avmm_w_waitrequest -> board:avmm_w_waitrequest
	wire  [511:0] board_avmm_w_readdata;                   // mm_interconnect_2:board_avmm_w_readdata -> board:avmm_w_readdata
	wire          board_avmm_w_debugaccess;                // board:avmm_w_debugaccess -> mm_interconnect_2:board_avmm_w_debugaccess
	wire   [63:0] board_avmm_w_address;                    // board:avmm_w_address -> mm_interconnect_2:board_avmm_w_address
	wire          board_avmm_w_read;                       // board:avmm_w_read -> mm_interconnect_2:board_avmm_w_read
	wire   [63:0] board_avmm_w_byteenable;                 // board:avmm_w_byteenable -> mm_interconnect_2:board_avmm_w_byteenable
	wire          board_avmm_w_readdatavalid;              // mm_interconnect_2:board_avmm_w_readdatavalid -> board:avmm_w_readdatavalid
	wire  [511:0] board_avmm_w_writedata;                  // board:avmm_w_writedata -> mm_interconnect_2:board_avmm_w_writedata
	wire          board_avmm_w_write;                      // board:avmm_w_write -> mm_interconnect_2:board_avmm_w_write
	wire    [4:0] board_avmm_w_burstcount;                 // board:avmm_w_burstcount -> mm_interconnect_2:board_avmm_w_burstcount
	wire          irq_mapper_receiver0_irq;                        // board:kernel_irq_irq -> irq_mapper:receiver0_irq
	wire    [0:0] board_kernel_irq_irq;                            // irq_mapper:sender_irq -> board:kernel_irq_irq
	wire          rst_controller_reset_out_reset;                  // rst_controller:reset_out -> [irq_mapper:reset, mm_interconnect_0:board_global_reset_reset_bridge_in_reset_reset, mm_interconnect_0:board_qpi_slave_translator_reset_reset_bridge_in_reset_reset]
  

  
  
  
  
  
  
  
  bsp_logic bsp_logic_inst (
        .pClk                ( pClk),
        .pClkDiv2            ( pClkDiv2),
        .pClkDiv4            ( pClkDiv4),
        .uClk_usr            ( uClk_usr),
        .uClk_usrDiv2        ( uClk_usrDiv2),
        .pck_cp2af_softReset ( pck_cp2af_softReset),
        .pck_cp2af_pwrState  ( pck_cp2af_pwrState),
        .pck_cp2af_error     ( pck_cp2af_error),
        
        .pck_af2cp_sTx       ( pck_af2cp_sTx),                // CCI-P Tx Port
        .pck_cp2af_sRx       ( pck_cp2af_sRx),               // CCI-P Rx Port
        
		.board_kernel_reset_reset_n 	  (board_kernel_reset_reset_n),
		.board_kernel_irq_irq       	  (board_kernel_irq_irq),
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
		.board_avmm_r_waitrequest       (board_avmm_r_waitrequest),
		.board_avmm_r_readdata          (board_avmm_r_readdata),
		.board_avmm_r_readdatavalid     (board_avmm_r_readdatavalid),
		.board_avmm_r_burstcount        (board_avmm_r_burstcount),
		.board_avmm_r_writedata         (board_avmm_r_writedata),
		.board_avmm_r_address           (board_avmm_r_address),
		.board_avmm_r_write             (board_avmm_r_write),
		.board_avmm_r_read              (board_avmm_r_read),
		.board_avmm_r_byteenable        (board_avmm_r_byteenable),
		.board_avmm_r_debugaccess       (board_avmm_r_debugaccess),
		.board_avmm_w_waitrequest       (board_avmm_w_waitrequest),
		.board_avmm_w_readdata          (board_avmm_w_readdata),
		.board_avmm_w_readdatavalid     (board_avmm_w_readdatavalid),
		.board_avmm_w_burstcount        (board_avmm_w_burstcount),
		.board_avmm_w_writedata         (board_avmm_w_writedata),
		.board_avmm_w_address           (board_avmm_w_address),
		.board_avmm_w_write             (board_avmm_w_write),
		.board_avmm_w_read              (board_avmm_w_read),
		.board_avmm_w_byteenable        (board_avmm_w_byteenable),
		.board_avmm_w_debugaccess       (board_avmm_w_debugaccess),
		.kernel_clk(pClkDiv4)
	);
  

  
	freeze_wrapper freeze_wrapper_inst (
    .freeze                     	  (1'b0),
		.board_kernel_clk_clk       	  (pClkDiv4),
		.board_kernel_clk2x_clk     	  (pClkDiv2 ),
		.board_kernel_reset_reset_n 	  (board_kernel_reset_reset_n),
		.board_kernel_irq_irq       	  (board_kernel_irq_irq),
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
		.board_avmm_r_waitrequest       (board_avmm_r_waitrequest),
		.board_avmm_r_readdata          (board_avmm_r_readdata),
		.board_avmm_r_readdatavalid     (board_avmm_r_readdatavalid),
		.board_avmm_r_burstcount        (board_avmm_r_burstcount),
		.board_avmm_r_writedata         (board_avmm_r_writedata),
		.board_avmm_r_address           (board_avmm_r_address),
		.board_avmm_r_write             (board_avmm_r_write),
		.board_avmm_r_read              (board_avmm_r_read),
		.board_avmm_r_byteenable        (board_avmm_r_byteenable),
		.board_avmm_r_debugaccess       (board_avmm_r_debugaccess),
		.board_avmm_w_waitrequest       (board_avmm_w_waitrequest),
		.board_avmm_w_readdata          (board_avmm_w_readdata),
		.board_avmm_w_readdatavalid     (board_avmm_w_readdatavalid),
		.board_avmm_w_burstcount        (board_avmm_w_burstcount),
		.board_avmm_w_writedata         (board_avmm_w_writedata),
		.board_avmm_w_address           (board_avmm_w_address),
		.board_avmm_w_write             (board_avmm_w_write),
		.board_avmm_w_read              (board_avmm_w_read),
		.board_avmm_w_byteenable        (board_avmm_w_byteenable),
		.board_avmm_w_debugaccess       (board_avmm_w_debugaccess)
	);


endmodule         
