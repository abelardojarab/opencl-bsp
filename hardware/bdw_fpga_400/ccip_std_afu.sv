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
  output          t_if_ccip_Tx      pck_af2cp_sTx,        // CCI-P Tx Port

  // OpenCL kernel freeze wrapper signal
  input           logic             opencl_freeze
);


localparam MPF_DFH_MMIO_ADDR = 'h1000;

//
// Expose FIU as an MPF interface
//


  
  
 

  

 
  
  

cci_mpf_if fiu(.clk(pClk));  
ccip_wires_to_mpf
  #(
    .REGISTER_INPUTS(0),
    .REGISTER_OUTPUTS(1)
    )
  map_ifc(
          .pClk                ( pClk),              // 16ui link/protocol clock domain. Interface Clock
        .pClkDiv2            ( 1'b0),              // 32ui link/protocol clock domain. Synchronous to interface clock
        .pClkDiv4            ( 1'b0),              // 64ui link/protocol clock domain. Synchronous to interface clock
        .uClk_usr            ( 1'b0),
        .uClk_usrDiv2        ( 1'b0),
        .pck_cp2af_softReset ( pck_cp2af_softReset),
        .pck_cp2af_pwrState  ( pck_cp2af_pwrState),
        .pck_cp2af_error     ( pck_cp2af_error),
        
        .pck_af2cp_sTx       ( pck_af2cp_sTx),         // CCI-P Tx Port
        .pck_cp2af_sRx      ( pck_cp2af_sRx),          // CCI-P Rx Port
        .fiu(fiu)
  );
  
//
// Put MPF between AFU and FIU.
//
cci_mpf_if afu(.clk(pClk));

cci_mpf
  #(
    .SORT_READ_RESPONSES(1),
    .PRESERVE_WRITE_MDATA(1),

    // Don't enforce write/write or write/read ordering within a cache line.
    // (Default CCI behavior.)
   .ENABLE_VC_MAP(1), 
   .ENABLE_DYNAMIC_VC_MAPPING(1),	
    .ENFORCE_WR_ORDER(1),
    .ENABLE_PARTIAL_WRITES(1),
    // Address of the MPF feature header
    .DFH_MMIO_BASE_ADDR(MPF_DFH_MMIO_ADDR)
    )
  mpf
   (
    .clk(pClk),
    .fiu,
    .afu
    );

    
    wire [63:0] tx_c1_byteen;
t_if_ccip_Rx afu_rx;
t_if_ccip_Tx afu_tx;


wire  nohazards_rd;     
wire nohazards_wr_full; 
wire nohazards_wr_all;
always_comb
begin
    afu_rx.c0 = afu.c0Rx;
    afu_rx.c1 = afu.c1Rx;

    afu_rx.c0TxAlmFull = afu.c0TxAlmFull;
    afu_rx.c1TxAlmFull = afu.c1TxAlmFull;

    afu.c0Tx = cci_mpf_cvtC0TxFromBase(afu_tx.c0);
    // Treat all addresses as virtual
    if (cci_mpf_c0TxIsReadReq(afu.c0Tx))
    begin
        afu.c0Tx.hdr.ext.addrIsVirtual = 1'b1;
            // Enable eVC_VA to physical channel mapping.  This will only
            // be triggered when ENABLE_VC_MAP is set above.
            afu.c0Tx.hdr.ext.mapVAtoPhysChannel = 1'b1;
            
            afu.c0Tx.hdr.ext.checkLoadStoreOrder = nohazards_rd ? 1'b0: 1'b1;
    end

    afu.c1Tx = cci_mpf_cvtC1TxFromBase(afu_tx.c1);
    if (cci_mpf_c1TxIsWriteReq(afu.c1Tx))
    begin
        afu.c1Tx.hdr.ext.addrIsVirtual = 1'b1;
            // Enable eVC_VA to physical channel mapping.  This will only
            // be triggered when ENABLE_VC_MAP is set above.
        afu.c1Tx.hdr.ext.mapVAtoPhysChannel = 1'b1;
        
        afu.c1Tx.hdr.ext.checkLoadStoreOrder = nohazards_wr_all ? 1'b0 :nohazards_wr_full ? tx_c1_byteen != {64{1'b1}} :  1'b1;
        afu.c1Tx.hdr.pwrite.isPartialWrite = tx_c1_byteen != {64{1'b1}};
        afu.c1Tx.hdr.pwrite.mask = tx_c1_byteen;
    end

    afu.c2Tx = afu_tx.c2;
end





    system u0 (
      .ci0_InitDone         (1'b1),         //   ci0.InitDone
      // TODO - make sure PLL is ok!
      //.kernel_pll_refclk_clk (pClkDiv2),
      .global_reset_reset_n (~afu_reset), //  global_reset.reset_n
      .clk_400_clk           (pClk),
      .bridge_reset_reset(pck_cp2af_softReset),
      .opencl_freeze (opencl_freeze), 
		.clk_200_clk           (pClk),  
		  .ci0_rx_c0_header                   (afu_rx.c0.hdr),
		  .ci0_rx_c0_data                     (afu_rx.c0.data),
		  .ci0_rx_c0_wrvalid                  (1'b0),
		  .ci0_rx_c0_rdvalid                  (afu_rx.c0.rspValid),
		  
      .ci0_rx_c0_ugvalid                  (1'b0),
      .ci0_rx_c0_mmiordvalid                 (afu_rx.c0.mmioRdValid),
      .ci0_rx_c0_mmiowrvalid                 (afu_rx.c0.mmioWrValid),
      
      
		  .ci0_rx_c1_header                   (afu_rx.c1.hdr),
		  .ci0_rx_c1_wrvalid                  (afu_rx.c1.rspValid),
		  .ci0_rx_c1_irvalid                  (1'b0),
		  
      
      .ci0_tx_c0_almostfull                  (afu_rx.c0TxAlmFull),
		  .ci0_tx_c1_almostfull                  (afu_rx.c1TxAlmFull),
      
      .ci0_tx_c1_byteen(    tx_c1_byteen),
		  .ci0_tx_c0_header                      (afu_tx.c0.hdr ),
		  .ci0_tx_c0_rdvalid                  (afu_tx.c0.valid ),
      
		  .ci0_tx_c1_header                      (afu_tx.c1.hdr ),
		  .ci0_tx_c1_data                     (afu_tx.c1.data ),
		  .ci0_tx_c1_wrvalid                  (afu_tx.c1.valid ),
		  .ci0_tx_c1_irvalid                ( ),
      
      .ci0_tx_c2_header                     (afu_tx.c2.hdr ),
		  .ci0_tx_c2_rdvalid                 (afu_tx.c2.mmioRdValid ),
		  .ci0_tx_c2_data                (afu_tx.c2.data ),
		  
		 .nohazards_rd  (nohazards_rd),   
         .nohazards_wr_full (nohazards_wr_full),
         .nohazards_wr_all (nohazards_wr_all)
      //.kernel_clk(kernel_clk)

    );


endmodule         
