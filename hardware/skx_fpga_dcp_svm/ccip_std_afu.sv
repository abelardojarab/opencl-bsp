// ***************************************************************************
// Copyright (c) 2013-2016, Intel Corporation
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
// Module Name :	  ccip_std_afu
// Project :        ccip afu top 
// Description :    This module instantiates CCI-P compliant AFU

// ***************************************************************************
`default_nettype none
import ccip_if_pkg::*;
module ccip_std_afu(
  // CCI-P Clocks and Resets
  pClk,                      // 400MHz - CCI-P clock domain. Primary interface clock
  pClkDiv2,                  // 200MHz - CCI-P clock domain.
  pClkDiv4,                  // 100MHz - CCI-P clock domain.
  uClk_usr,                  // User clock domain. Refer to clock programming guide  ** Currently provides fixed 300MHz clock **
  uClk_usrDiv2,              // User clock domain. Half the programmed frequency  ** Currently provides fixed 150MHz clock **
  pck_cp2af_softReset,       // CCI-P ACTIVE HIGH Soft Reset
  pck_cp2af_pwrState,        // CCI-P AFU Power State
  pck_cp2af_error,           // CCI-P Protocol Error Detected
  
`ifdef INCLUDE_DDR4
  DDR4_USERCLK,
  DDR4a_waitrequest,
  DDR4a_readdata,
  DDR4a_readdatavalid,
  DDR4a_burstcount,
  DDR4a_writedata,
  DDR4a_address,
  DDR4a_write,
  DDR4a_read,
  DDR4a_byteenable,
  DDR4b_waitrequest,
  DDR4b_readdata,
  DDR4b_readdatavalid,
  DDR4b_burstcount,
  DDR4b_writedata,
  DDR4b_address,
  DDR4b_write,
  DDR4b_read,
  DDR4b_byteenable,
`endif

  // Interface structures
  pck_cp2af_sRx,             // CCI-P Rx Port
  pck_af2cp_sTx              // CCI-P Tx Port
);
  input           wire             pClk;                     // 400MHz - CCI-P clock domain. Primary interface clock
  input           wire             pClkDiv2;                 // 200MHz - CCI-P clock domain.
  input           wire             pClkDiv4;                 // 100MHz - CCI-P clock domain.
  input           wire             uClk_usr;                 // User clock domain. Refer to clock programming guide  ** Currently provides fixed 300MHz clock **
  input           wire             uClk_usrDiv2;             // User clock domain. Half the programmed frequency  ** Currently provides fixed 150MHz clock **
  input           wire             pck_cp2af_softReset;      // CCI-P ACTIVE HIGH Soft Reset
  input           wire [1:0]       pck_cp2af_pwrState;       // CCI-P AFU Power State
  input           wire             pck_cp2af_error;          // CCI-P Protocol Error Detected
`ifdef INCLUDE_DDR4 
  input   wire                          DDR4_USERCLK;
  input   wire                          DDR4a_waitrequest;
  input   wire [511:0]                  DDR4a_readdata;
  input   wire                          DDR4a_readdatavalid;
  output  wire [6:0]                    DDR4a_burstcount;
  output  wire [511:0]                  DDR4a_writedata;
  output  wire [25:0]                   DDR4a_address;
  output  wire                          DDR4a_write;
  output  wire                          DDR4a_read;
  output  wire [63:0]                   DDR4a_byteenable;
  input   wire                          DDR4b_waitrequest;
  input   wire [511:0]                  DDR4b_readdata;
  input   wire                          DDR4b_readdatavalid;
  output  wire [6:0]                    DDR4b_burstcount;
  output  wire [511:0]                  DDR4b_writedata;
  output  wire [25:0]                   DDR4b_address;
  output  wire                          DDR4b_write;
  output  wire                          DDR4b_read;
  output  wire [63:0]                   DDR4b_byteenable;
`endif
  // Interface structures
  input           t_if_ccip_Rx     pck_cp2af_sRx;           // CCI-P Rx Port
  output          t_if_ccip_Tx     pck_af2cp_sTx;           // CCI-P Tx Port

  
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
		.kernel_clk(uClk_usrDiv2)
	);
  

  
	freeze_wrapper freeze_wrapper_inst (
    .freeze                     	  (1'b0),
		.board_kernel_clk_clk       	  (uClk_usrDiv2),
		.board_kernel_clk2x_clk     	  (uClk_usr ),
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

