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

// Include MPF data types, including the CCI interface pacakge.
`include "cci_mpf_if.vh"
import cci_mpf_csrs_pkg::*;

`ifndef OPENCL_MEMORY_ADDR_WIDTH
`define OPENCL_MEMORY_ADDR_WIDTH 26
`endif

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
  DDR4a_USERCLK,
  DDR4a_waitrequest,
  DDR4a_readdata,
  DDR4a_readdatavalid,
  DDR4a_burstcount,
  DDR4a_writedata,
  DDR4a_address,
  DDR4a_write,
  DDR4a_read,
  DDR4a_byteenable,
  DDR4b_USERCLK,
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
	
	// Start by registering reset
	(* preserve *) logic pck_cp2af_softReset_q = 1'b1;
	(* preserve *) logic pck_cp2af_softReset_q2 = 1'b1;
	always @(posedge pClk)
	begin
		pck_cp2af_softReset_q <= pck_cp2af_softReset;
		pck_cp2af_softReset_q2 <= pck_cp2af_softReset_q;
	end
	
`ifdef INCLUDE_DDR4 
	input   wire                          DDR4a_USERCLK;
	input   wire                          DDR4a_waitrequest;
	input   wire [511:0]                  DDR4a_readdata;
	input   wire                          DDR4a_readdatavalid;
	output  wire [6:0]                    DDR4a_burstcount;
	output  wire [511:0]                  DDR4a_writedata;
	output  wire [`OPENCL_MEMORY_ADDR_WIDTH-1:0]                   DDR4a_address;
	output  wire                          DDR4a_write;
	output  wire                          DDR4a_read;
	output  wire [63:0]                   DDR4a_byteenable;
	input   wire                          DDR4b_USERCLK;
	input   wire                          DDR4b_waitrequest;
	input   wire [511:0]                  DDR4b_readdata;
	input   wire                          DDR4b_readdatavalid;
	output  wire [6:0]                    DDR4b_burstcount;
	output  wire [511:0]                  DDR4b_writedata;
	output  wire [`OPENCL_MEMORY_ADDR_WIDTH-1:0]                   DDR4b_address;
	output  wire                          DDR4b_write;
	output  wire                          DDR4b_read;
	output  wire [63:0]                   DDR4b_byteenable;
`else
	wire          DDR4a_waitrequest;
	wire [511:0]  DDR4a_readdata;
	wire          DDR4a_readdatavalid;
	wire [6:0]   DDR4a_burstcount;
	wire [511:0] DDR4a_writedata;
	wire [`OPENCL_MEMORY_ADDR_WIDTH-1:0]  DDR4a_address;
	wire         DDR4a_write;
	wire         DDR4a_read;
	wire [63:0]  DDR4a_byteenable;
	wire          DDR4b_waitrequest;
	wire [511:0]  DDR4b_readdata;
	wire          DDR4b_readdatavalid;
	wire [6:0]   DDR4b_burstcount;
	wire [511:0] DDR4b_writedata;
	wire [`OPENCL_MEMORY_ADDR_WIDTH-1:0]  DDR4b_address;
	wire [63:0]  DDR4b_byteenable;
	wire         DDR4b_write;
	wire         DDR4b_read;
	
	`timescale 1 ps / 1 ps
	reg          DDR4a_USERCLK = 0;  
	always begin
		#1875 DDR4a_USERCLK = ~DDR4a_USERCLK;
	end
	
	reg          DDR4b_USERCLK = 0;  
	always begin
		#1800 DDR4b_USERCLK = ~DDR4b_USERCLK;
	end
	
	mem_sim_model #(
		.AVMM_ADDR_WIDTH(`OPENCL_MEMORY_ADDR_WIDTH)
		)
		ddr4a_inst(
		.clk(DDR4a_USERCLK),
		.reset(pck_cp2af_softReset_q2),
		.avmm_waitrequest(DDR4a_waitrequest),
		.avmm_readdata(DDR4a_readdata),
		.avmm_readdatavalid(DDR4a_readdatavalid),
		.avmm_burstcount(DDR4a_burstcount),
		.avmm_writedata(DDR4a_writedata),
		.avmm_address(DDR4a_address),
		.avmm_write(DDR4a_write),
		.avmm_read(DDR4a_read),
		.avmm_byteenable(DDR4a_byteenable)
	);
	
	mem_sim_model #(
		.AVMM_ADDR_WIDTH(`OPENCL_MEMORY_ADDR_WIDTH)
		)
		ddr4b_inst(
		.clk(DDR4b_USERCLK),
		.reset(pck_cp2af_softReset_q2),
		.avmm_waitrequest(DDR4b_waitrequest),
		.avmm_readdata(DDR4b_readdata),
		.avmm_readdatavalid(DDR4b_readdatavalid),
		.avmm_burstcount(DDR4b_burstcount),
		.avmm_writedata(DDR4b_writedata),
		.avmm_address(DDR4b_address),
		.avmm_write(DDR4b_write),
		.avmm_read(DDR4b_read),
		.avmm_byteenable(DDR4b_byteenable)
	);
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
	wire          irq_mapper_receiver0_irq;                        // board:kernel_irq_irq -> irq_mapper:receiver0_irq
	wire    [0:0] board_kernel_irq_irq;                            // irq_mapper:sender_irq -> board:kernel_irq_irq
	wire          rst_controller_reset_out_reset;                  // rst_controller:reset_out -> [irq_mapper:reset, mm_interconnect_0:board_global_reset_reset_bridge_in_reset_reset, mm_interconnect_0:board_qpi_slave_translator_reset_reset_bridge_in_reset_reset]
	
	wire	[`OPENCL_MEMORY_ADDR_WIDTH+6:0]	acl_internal_snoop_data;
	wire		acl_internal_snoop_valid;
	wire		acl_internal_snoop_ready;  
	
	wire		kernel_ddr4a_waitrequest;
	wire	[511:0]	kernel_ddr4a_readdata;
	wire		kernel_ddr4a_readdatavalid;
	wire	[4:0]	kernel_ddr4a_burstcount;
	wire	[511:0]	kernel_ddr4a_writedata;
	wire	[`OPENCL_MEMORY_ADDR_WIDTH+6-1:0]	kernel_ddr4a_address;
	wire		kernel_ddr4a_write;
	wire		kernel_ddr4a_read;
	wire	[63:0]	kernel_ddr4a_byteenable;
	wire		kernel_ddr4a_debugaccess;
	wire		kernel_ddr4b_waitrequest;
	wire	[511:0]	kernel_ddr4b_readdata;
	wire		kernel_ddr4b_readdatavalid;
	wire	[4:0]	kernel_ddr4b_burstcount;
	wire	[511:0]	kernel_ddr4b_writedata;
	wire	[`OPENCL_MEMORY_ADDR_WIDTH+6-1:0]	kernel_ddr4b_address;
	wire		kernel_ddr4b_write;
	wire		kernel_ddr4b_read;
	wire	[63:0]	kernel_ddr4b_byteenable;
	wire		kernel_ddr4b_debugaccess;
	
	wire [5:0]	ddr4a_byte_address_bits;
	wire [5:0]	ddr4b_byte_address_bits;

	//register tx/rx inputs
	//almost full signals can be registered because async fifo has slack

	//this assignment prevents these registers from being inferred into a ram
	(* altera_attribute = "-name auto_shift_register_recognition OFF" *)
	t_if_ccip_Rx     pck_cp2af_sRx_q;           // CCI-P Rx Port
	(* altera_attribute = "-name auto_shift_register_recognition OFF" *)
	t_if_ccip_Tx     pck_af2cp_sTx_q;           // CCI-P Tx Port

	always @(posedge pClk)
	begin
		pck_af2cp_sTx <= pck_af2cp_sTx_q;
		pck_cp2af_sRx_q <= pck_cp2af_sRx;
	end

    //ccip async shim
    wire 	  async_shim_reset_out;   
    wire 	  afu_clk;   
    
    t_if_ccip_Tx async2af_sTxPort;
    t_if_ccip_Rx async2af_sRxPort;
   
    assign afu_clk = pClkDiv2 ;
    t_if_ccip_c0_Rx async2af_mmio_c0rx;

    ccip_async_shim #(
	.C0TX_DEPTH_RADIX(7),   //default was 8
	.C1TX_DEPTH_RADIX(7),   //default was 8
	.C2TX_DEPTH_RADIX(7),   //default was 8
	.ENABLE_SEPARATE_MMIO_FIFO(1),
	.C0RX_MMIO_DEPTH_RADIX(9), //default was 9
	//For DCP only 256 is needed.  Using 512 so that the RX to TX depth ratio is 4:1 to ensure for each 4CL read there are 4 beats of space in the response
	.C0RX_DEPTH_RADIX(9),	//default was 10
	.C1RX_DEPTH_RADIX(9)	//default was 10
    )
    ccip_async_shim (
				    .bb_softreset    (pck_cp2af_softReset_q2),
				    .bb_clk          (pClk),
				    .bb_tx           (pck_af2cp_sTx_q),
				    .bb_rx           (pck_cp2af_sRx_q),
				    .afu_softreset   (async_shim_reset_out),
				    .afu_clk         (afu_clk),
				    .afu_tx          (async2af_sTxPort),
				    .afu_rx          (async2af_sRxPort),
				    .afu_mmio_c0rx   (async2af_mmio_c0rx)
				    );

    // ====================================================================
    //
    //  Instantiate a memory properties factory (MPF) between the external
    //  interface and the AFU, adding support for virtual memory and
    //  control over memory ordering.
    //
    // ====================================================================

    //
    // The AFU exposes the primary AFU device feature header (DFH) at MMIO
    // address 0.  MPF defines a set of its own DFHs.  The AFU must
    // build its feature chain to point to the MPF chain.  The AFU must
    // also tell the MPF module the MMIO address at which MPF should start
    // its feature chain.
    //
    //Note: with ENABLE_SEPARATE_MMIO_FIFO, MPF will not receive or forward
    //any mmio requests
    localparam MPF_DFH_MMIO_ADDR = 'h0000;
    localparam MPF_DFH_MMIO_NEXT_ADDR = 'h0000;

    //
    // MPF represents CCI as a SystemVerilog interface, derived from the
    // same basic types defined in ccip_if_pkg.  Interfaces reduce the
    // number of internal MPF module parameters, since each internal MPF
    // shim has a bus connected toward the AFU and a bus connected toward
    // the FIU.
    //

    //
    // Expose FIU as an MPF interface
    //
    cci_mpf_if fiu(.clk(afu_clk));

    // The CCI wires to MPF mapping connections have identical naming to
    // the standard AFU.  The module exports an interface named "fiu".
    ccip_wires_to_mpf
      #(
        // All inputs and outputs in PR region (AFU) must be registered!
        .REGISTER_INPUTS(1),
        .REGISTER_OUTPUTS(1)
        )
      map_ifc
       (
        .pClk(afu_clk),
        .pck_cp2af_softReset(async_shim_reset_out),
        .pck_cp2af_sRx(async2af_sRxPort),
        .pck_af2cp_sTx(async2af_sTxPort),
        .*
        );

    //
    // Instantiate MPF with the desired properties.
    //
    cci_mpf_if afu(.clk(afu_clk));

    cci_mpf
      #(
        // Should read responses be returned in the same order that
        // the reads were requested?
        .SORT_READ_RESPONSES(1),

        // Should the Mdata from write requests be returned in write
        // responses?  If the AFU is simply counting write responses
        // and isn't consuming Mdata, then setting this to 0 eliminates
        // the memory and logic inside MPF for preserving Mdata.
        .PRESERVE_WRITE_MDATA(0),

        // Enable virtual to physical translation?  When enabled, MPF
        // accepts requests with either virtual or physical addresses.
        // Virtual addresses are indicated by setting the
        // addrIsVirtual flag in the MPF extended Tx channel
        // request header.
        .ENABLE_VTP(0),

        // Enable mapping of eVC_VA to physical channels?  AFUs that both use
        // eVC_VA and read back memory locations written by the AFU must either
        // emit WrFence on VA or use explicit physical channels and enforce
        // write/read order.  Each method has tradeoffs.  WrFence VA is expensive
        // and should be emitted only infrequently.  Memory requests to eVC_VA
        // may have higher bandwidth than explicit mapping.  The MPF module for
        // physical channel mapping is optimized for each CCI platform.
        //
        // If you set ENFORCE_WR_ORDER below you probably also want to set
        // ENABLE_VC_MAP.
        //
        // The mapVAtoPhysChannel extended header bit must be set on each
        // request to enable mapping.
        .ENABLE_VC_MAP(0),
        // When ENABLE_VC_MAP is set the mapping is either static for the entire
        // run or dynamic, changing in response to traffic patterns.  The mapper
        // guarantees synchronization when the mapping changes by emitting a
        // WrFence on eVC_VA and draining all reads.  Ignored when ENABLE_VC_MAP
        // is 0.
        .ENABLE_DYNAMIC_VC_MAPPING(0),

        // Should write/write and write/read ordering within a cache
        // be enforced?  By default CCI makes no guarantees on the order
        // in which operations to the same cache line return.  Setting
        // this to 1 adds logic to filter reads and writes to ensure
        // that writes retire in order and the reads correspond to the
        // most recent write.
        //
        // ***  Even when set to 1, MPF guarantees order only within
        // ***  a given virtual channel.  There is no guarantee of
        // ***  order across virtual channels and no guarantee when
        // ***  using eVC_VA, since it spreads requests across all
        // ***  channels.  Synchronizing writes across virtual channels
        // ***  can be accomplished only by requesting a write fence on
        // ***  eVC_VA.  Syncronizing writes across virtual channels
        // ***  and then reading back the same data requires both
        // ***  requesting a write fence on eVC_VA and waiting for the
        // ***  corresponding write fence response.
        //
        .ENFORCE_WR_ORDER(0),

        // Enable partial write emulation.  CCI has no support for masked
        // writes that merge new data with existing data in a line.  MPF
        // adds byte-level masks to the write request header and emulates
        // partial writes as a read-modify-write operation.  When coupled
        // with ENFORCE_WR_ORDER, partial writes are free of races on the
        // FPGA side.  There are no guarantees of atomicity and there is
        // no protection against races with CPU-generates writes.
        .ENABLE_PARTIAL_WRITES(0),

        // Address of the MPF feature header.  See comment above.
        .DFH_MMIO_BASE_ADDR(MPF_DFH_MMIO_ADDR),
        .DFH_MMIO_NEXT_ADDR(MPF_DFH_MMIO_NEXT_ADDR)
        )
      mpf
       (
        .clk(afu_clk),
        .fiu,
        .afu,
        .c0NotEmpty(),
        .c1NotEmpty()
        );


    // ====================================================================
    //
    //  Now CCI is exposed as an MPF interface through the object named
    //  "afu".  Two primary strategies are available for connecting
    //  a design to the interface:
    //
    //    (1) Use the MPF-provided constructor functions to generate
    //        CCI request structures and pass them directly to MPF.
    //        See, for example, cci_mpf_defaultReqHdrParams() and
    //        cci_c0_genReqHdr() in cci_mpf_if_pkg.sv.
    //
    //    (1) Map "afu" back to standard CCI wires.  This is the strategy
    //        used below to map an existing AFU to MPF.
    //
    // ====================================================================

    //
    // Convert MPF interfaces back to the standard CCI structures.
    //
    t_if_ccip_Rx mpf2af_sRxPort;
    t_if_ccip_Tx af2mpf_sTxPort;

    //
    // The cci_mpf module has already registered the Rx wires heading
    // toward the AFU, so wires are acceptable.
    //
    always_comb
    begin
        mpf2af_sRxPort.c0 = afu.c0Rx;
        mpf2af_sRxPort.c1 = afu.c1Rx;

        mpf2af_sRxPort.c0TxAlmFull = afu.c0TxAlmFull;
        mpf2af_sRxPort.c1TxAlmFull = afu.c1TxAlmFull;

        afu.c0Tx = cci_mpf_cvtC0TxFromBase(af2mpf_sTxPort.c0);
        if (cci_mpf_c0TxIsReadReq(afu.c0Tx))
        begin
            // Treat all addresses as virtual.
            afu.c0Tx.hdr.ext.addrIsVirtual = 1'b0;

            // Enable eVC_VA to physical channel mapping.  This will only
            // be triggered when ENABLE_VC_MAP is set above.
            afu.c0Tx.hdr.ext.mapVAtoPhysChannel = 1'b0;

            // Enforce load/store and store/store ordering within lines.
            // This will only be triggered when ENFORCE_WR_ORDER is set.
            afu.c0Tx.hdr.ext.checkLoadStoreOrder = 1'b0;
        end

        afu.c1Tx = cci_mpf_cvtC1TxFromBase(af2mpf_sTxPort.c1);
        if (cci_mpf_c1TxIsWriteReq(afu.c1Tx))
        begin
            // Treat all addresses as virtual.
            afu.c1Tx.hdr.ext.addrIsVirtual = 1'b0;

            // Enable eVC_VA to physical channel mapping.  This will only
            // be triggered when ENABLE_VC_MAP is set above.
            afu.c1Tx.hdr.ext.mapVAtoPhysChannel = 1'b0;

            // Enforce load/store and store/store ordering within lines.
            // This will only be triggered when ENFORCE_WR_ORDER is set.
            afu.c1Tx.hdr.ext.checkLoadStoreOrder = 1'b0;
        end

        afu.c2Tx = af2mpf_sTxPort.c2;
    end

//===============================================================================================
// User AFU goes here
//===============================================================================================

  bsp_logic #(
		.MMIO_BYPASS_ADDRESS(MPF_DFH_MMIO_ADDR),
		.MMIO_BYPASS_SIZE(CCI_MPF_MMIO_SIZE)
	)  bsp_logic_inst (
		.clk            ( afu_clk ),
		
		.reset ( fiu.reset ) ,
		.pck_cp2af_sRx       ( mpf2af_sRxPort ) ,
		.pck_af2cp_sTx       ( af2mpf_sTxPort ) ,
		.cp2af_mmio_c0rx     ( async2af_mmio_c0rx ) ,
		
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
		
		
		.acl_internal_snoop_data(acl_internal_snoop_data),
		.acl_internal_snoop_valid(acl_internal_snoop_valid),
		.acl_internal_snoop_ready(acl_internal_snoop_ready),
		
		.emif_ddr4a_clk(DDR4a_USERCLK),
		.emif_ddr4b_clk(DDR4b_USERCLK),
		
		.emif_ddr4a_waitrequest(DDR4a_waitrequest),
		.emif_ddr4a_readdata(DDR4a_readdata),
		.emif_ddr4a_readdatavalid(DDR4a_readdatavalid),
		.emif_ddr4a_burstcount(DDR4a_burstcount),
		.emif_ddr4a_writedata(DDR4a_writedata),
		.emif_ddr4a_address({DDR4a_address, ddr4a_byte_address_bits}),
		.emif_ddr4a_write(DDR4a_write),
		.emif_ddr4a_read(DDR4a_read),
		.emif_ddr4a_byteenable(DDR4a_byteenable),
		.emif_ddr4a_debugaccess(),
		
		.emif_ddr4b_waitrequest(DDR4b_waitrequest),
		.emif_ddr4b_readdata(DDR4b_readdata),
		.emif_ddr4b_readdatavalid(DDR4b_readdatavalid),
		.emif_ddr4b_burstcount(DDR4b_burstcount),
		.emif_ddr4b_writedata(DDR4b_writedata),
		.emif_ddr4b_address({DDR4b_address, ddr4b_byte_address_bits}),
		.emif_ddr4b_write(DDR4b_write),
		.emif_ddr4b_read(DDR4b_read),
		.emif_ddr4b_byteenable(DDR4b_byteenable),
		.emif_ddr4b_debugaccess(),
		
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
		
		.acl_internal_snoop_data(acl_internal_snoop_data),
		.acl_internal_snoop_valid(acl_internal_snoop_valid),
		.acl_internal_snoop_ready(acl_internal_snoop_ready),
		
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
		.kernel_ddr4b_debugaccess(kernel_ddr4b_debugaccess)
	);

endmodule

