`include "fpga_defines.vh"
import ccip_if_pkg::*;
`ifdef INCLUDE_ETHERNET
import hssi_eth_pkg::*;
`endif 
parameter CCIP_TXPORT_WIDTH = $bits(t_if_ccip_Tx);  // TODO: Move this to ccip_if_pkg
parameter CCIP_RXPORT_WIDTH = $bits(t_if_ccip_Rx);  // TODO: Move this to ccip_if_pkg

module green_bs
(
   // CCI-P Interface
   input   logic                         Clk_400,             // Core clock. CCI interface is synchronous to this clock.
   input   logic                         Clk_200,             // Core clock. CCI interface is synchronous to this clock.
   input   logic                         Clk_100,             // Core clock. CCI interface is synchronous to this clock.
   input   logic                         uClk_usr,             
   input   logic                         uClk_usrDiv2,         
   input   logic                         SoftReset,           // CCI interface reset. The Accelerator IP must use this Reset. ACTIVE HIGH
   input   logic [1:0]                   pck_cp2af_pwrState,
   input   logic                         pck_cp2af_error,
   output  logic [CCIP_TXPORT_WIDTH-1:0] bus_ccip_Tx,         // CCI-P TX port
   input   logic [CCIP_RXPORT_WIDTH-1:0] bus_ccip_Rx,         // CCI-P RX port
   
`ifdef INCLUDE_DDR4
     input                    DDR4_USERCLK,
     input                    DDR4a_waitrequest,
     input  [511:0]           DDR4a_readdata,
     input                    DDR4a_readdatavalid,
     output  [6:0]            DDR4a_burstcount,
     output  [511:0]          DDR4a_writedata,
     output  [25:0]           DDR4a_address,
     output                   DDR4a_write,
     output                   DDR4a_read,
     output  [63:0]           DDR4a_byteenable,
     input                    DDR4b_waitrequest,
     input  [511:0]           DDR4b_readdata,
     input                    DDR4b_readdatavalid,
     output  [6:0]            DDR4b_burstcount,
     output  [511:0]          DDR4b_writedata,
     output  [25:0]           DDR4b_address,
     output                   DDR4b_write,
     output                   DDR4b_read,
     output  [63:0]           DDR4b_byteenable,
`endif

`ifdef INCLUDE_ETHERNET
   // HSSI Ethernet SERDES Interface
     output  [NUM_LN-1:0]     tx_analogreset,
	 output  [NUM_LN-1:0]     tx_digitalreset,
	 output  [NUM_LN-1:0]     rx_analogreset,
	 output  [NUM_LN-1:0]     rx_digitalreset,
	 input                    tx_cal_busy,
	 input                    rx_cal_busy,
	 output  [NUM_LN-1:0]     rx_seriallpbken,
	 output  [NUM_LN-1:0]     rx_set_locktodata,
	 output  [NUM_LN-1:0]     rx_set_locktoref,
	 input   [NUM_LN-1:0]     rx_is_lockedtoref,
	 input   [NUM_LN-1:0]     rx_is_lockedtodata,
	 input                    tx_pll_locked,
	 
	 input                    tx_common_clk,
	 input                    tx_common_clk2,    
	 input                    tx_common_locked,
	 input                    rx_common_clk,
	 input                    rx_common_clk2,    
	 input                    rx_common_locked,
	 
	 output  [NUM_LN*128-1:0] tx_parallel_data,
	 input   [NUM_LN*128-1:0] rx_parallel_data,
	 input   [NUM_LN*20-1:0]  rx_control,              
	 output  [NUM_LN*18-1:0]  tx_control, 
//	 output  [NUM_LN-1:0]     rx_bitslip,
	 output  [NUM_LN-1:0]     tx_enh_data_valid,
	 input   [NUM_LN-1:0]     tx_enh_fifo_full,
	 input   [NUM_LN-1:0]     tx_enh_fifo_pfull,
	 input   [NUM_LN-1:0]     tx_enh_fifo_empty,
	 input   [NUM_LN-1:0]     tx_enh_fifo_pempty,
	 output  [NUM_LN-1:0]     rx_enh_fifo_rd_en,
	 input   [NUM_LN-1:0]     rx_enh_data_valid,
	 input   [NUM_LN-1:0]     rx_enh_fifo_full,
	 input   [NUM_LN-1:0]     rx_enh_fifo_pfull,
	 input   [NUM_LN-1:0]     rx_enh_fifo_empty,
	 input   [NUM_LN-1:0]     rx_enh_fifo_pempty,
//	 output  [NUM_LN-1:0]     rx_enh_fifo_align_clr,
	 input   [NUM_LN-1:0]     rx_enh_blk_lock,         
//	 input   [NUM_LN-1:0]     rx_enh_fifo_del,         
//	 input   [NUM_LN-1:0]     rx_enh_fifo_insert,      
	 input   [NUM_LN-1:0]     rx_enh_highber,          
//	 input   [NUM_LN-1:0]     rx_pma_div_clkout,       
//	 input   [NUM_LN-1:0]     tx_pma_div_clkout,

     output                   init_start,       
     input                    init_done,
	 	
	 // little management port
	 input                    prmgmt_ctrl_clk,
	 input   [15:0]           prmgmt_cmd,
	 input   [15:0]           prmgmt_addr,
	 input   [31:0]           prmgmt_din,
	 output  [31:0]           prmgmt_dout,
     input                    prmgmt_freeze,
     input                    prmgmt_arst,
     input                    prmgmt_ram_ena,
     output                   prmgmt_fatal_err,
`endif // INCLUDE_ETHERNET
`ifdef INCLUDE_GPIO
     output  [4:0] g2b_GPIO_a         ,// GPIO port A
     output  [4:0] g2b_GPIO_b         ,// GPIO port B
     output        g2b_I2C0_scl       ,// I2C0 clock
     output        g2b_I2C0_sda       ,// I2C0 data
     output        g2b_I2C0_rstn      ,// I2C0 rstn
     output        g2b_I2C1_scl       ,// I2C1 clock
     output        g2b_I2C1_sda       ,// I2C1 data
     output        g2b_I2C1_rstn      ,// I2C1 rstn

     input   [4:0] b2g_GPIO_a         ,// GPIO port A
     input   [4:0] b2g_GPIO_b         ,// GPIO port B
     input         b2g_I2C0_scl       ,// I2C0 clock
     input         b2g_I2C0_sda       ,// I2C0 data
     input         b2g_I2C0_rstn      ,// I2C0 rstn
     input         b2g_I2C1_scl       ,// I2C1 clock
     input         b2g_I2C1_sda       ,// I2C1 data
     input         b2g_I2C1_rstn      ,// I2C1 rstn

     output  [4:0] oen_GPIO_a         ,// GPIO port A
     output  [4:0] oen_GPIO_b         ,// GPIO port B
     output        oen_I2C0_scl       ,// I2C0 clock
     output        oen_I2C0_sda       ,// I2C0 data
     output        oen_I2C0_rstn      ,// I2C0 rstn
     output        oen_I2C1_scl       ,// I2C1 clock
     output        oen_I2C1_sda       ,// I2C1 data
     output        oen_I2C1_rstn      ,// I2C1 rstn
`endif
   // JTAG Interface for PR region debug
   input   logic            sr2pr_tms,
   input   logic            sr2pr_tdi,             
   output  logic            pr2sr_tdo,             
   input   logic            sr2pr_tck
);

t_if_ccip_Tx af2cp_sTxPort;
t_if_ccip_Rx cp2af_sRxPort;

always_comb
begin
  bus_ccip_Tx      = af2cp_sTxPort;
  cp2af_sRxPort    = bus_ccip_Rx;
end

// ===========================================
// AFU - Remote Debug JTAG IP instantiation
// ===========================================

`ifdef SIM_MODE
  assign pr2sr_tdo = 0;
`else
  `ifdef INCLUDE_REMOTE_STP
    wire loopback;
    sld_virtual_jtag 
    inst_sld_virtual_jtag (
          .tdi (loopback), 
          .tdo (loopback)
    );
  
    SCJIO 
    inst_SCJIO (
    		.tms         (sr2pr_tms),         //        jtag.tms
    		.tdi         (sr2pr_tdi),         //            .tdi
    		.tdo         (pr2sr_tdo),         //            .tdo
    		.tck         (sr2pr_tck)          //         tck.clk
    ); 
  `else
    assign pr2sr_tdo = 0;
  `endif // SIM_MODE
`endif // SIM_MODE

// ===========================================
// CCIP_STD_AFU Instantiation 
// ===========================================

ccip_std_afu inst_ccip_std_afu ( 
  .pClk                   (Clk_400),               // 16ui link/protocol clock domain. Interface Clock
  .pClkDiv2               (Clk_200),               // 32ui link/protocol clock domain. Synchronous to interface clock
  .pClkDiv4               (Clk_100),               // 64ui link/protocol clock domain. Synchronous to interface clock
  .uClk_usr               (uClk_usr),
  .uClk_usrDiv2           (uClk_usrDiv2),  
`ifdef INCLUDE_DDR4
  .DDR4_USERCLK           (DDR4_USERCLK),     
  .DDR4a_waitrequest      (DDR4a_waitrequest),
  .DDR4a_readdata         (DDR4a_readdata),
  .DDR4a_readdatavalid    (DDR4a_readdatavalid),
  .DDR4a_burstcount       (DDR4a_burstcount),
  .DDR4a_writedata        (DDR4a_writedata),
  .DDR4a_address          (DDR4a_address),
  .DDR4a_write            (DDR4a_write),
  .DDR4a_read             (DDR4a_read),
  .DDR4a_byteenable       (DDR4a_byteenable),
  .DDR4b_waitrequest      (DDR4b_waitrequest),
  .DDR4b_readdata         (DDR4b_readdata),
  .DDR4b_readdatavalid    (DDR4b_readdatavalid),
  .DDR4b_burstcount       (DDR4b_burstcount),
  .DDR4b_writedata        (DDR4b_writedata),
  .DDR4b_address          (DDR4b_address),
  .DDR4b_byteenable       (DDR4b_byteenable),
  .DDR4b_write            (DDR4b_write),
  .DDR4b_read             (DDR4b_read),
`endif
  .pck_cp2af_softReset    (SoftReset),
  .pck_cp2af_pwrState     (pck_cp2af_pwrState),
  .pck_cp2af_error        (pck_cp2af_error),                   
  .pck_af2cp_sTx          (af2cp_sTxPort),         // CCI-P Tx Port
  .pck_cp2af_sRx          (cp2af_sRxPort)          // CCI-P Rx Port
);

// ======================================================
// Workaround: To preserve uClk_usr routing to  PR region
// ======================================================

(* noprune *) logic uClk_usr_q1, uClk_usr_q2;
(* noprune *) logic uClk_usrDiv2_q1, uClk_usrDiv2_q2;
(* noprune *) logic pClkDiv4_q1, pClkDiv4_q2;
(* noprune *) logic pClkDiv2_q1, pClkDiv2_q2;

always  @(posedge uClk_usr)
begin
  uClk_usr_q1     <= uClk_usr_q2;
  uClk_usr_q2     <= !uClk_usr_q1;
end

always  @(posedge uClk_usrDiv2)
begin
  uClk_usrDiv2_q1 <= uClk_usrDiv2_q2;
  uClk_usrDiv2_q2 <= !uClk_usrDiv2_q1;
end

always  @(posedge Clk_100)
begin
  pClkDiv4_q1     <= pClkDiv4_q2;
  pClkDiv4_q2     <= !pClkDiv4_q1;
end

always  @(posedge Clk_200)
begin
  pClkDiv2_q1     <= pClkDiv2_q2;
  pClkDiv2_q2     <= !pClkDiv2_q1;
end

////////////////////////////////////////////////////////
// Partial reconfig zone
////////////////////////////////////////////////////////
`ifdef INCLUDE_ETHERNET
green_hssi_if prz0 (
	.tx_analogreset(tx_analogreset),
	.tx_digitalreset(tx_digitalreset),
	.rx_analogreset(rx_analogreset),
	.rx_digitalreset(rx_digitalreset),
	.tx_cal_busy(tx_cal_busy),
	.rx_cal_busy(rx_cal_busy),
	.rx_seriallpbken(rx_seriallpbken),
	.rx_set_locktodata(rx_set_locktodata),
	.rx_set_locktoref(rx_set_locktoref),
	.rx_is_lockedtoref(rx_is_lockedtoref),
	.rx_is_lockedtodata(rx_is_lockedtodata),
    .tx_pll_locked(tx_pll_locked),	
	
	.tx_common_clk(tx_common_clk),
	.tx_common_clk2(tx_common_clk2),
	.tx_common_locked(tx_common_locked),
	.rx_common_clk(rx_common_clk),
	.rx_common_clk2(rx_common_clk2),
	.rx_common_locked(rx_common_locked),
		
	.tx_parallel_data(tx_parallel_data),
	.rx_parallel_data(rx_parallel_data),
	.rx_control(rx_control),
	.tx_control(tx_control),
//	.rx_bitslip(rx_bitslip),
	.tx_enh_data_valid(tx_enh_data_valid),
	.tx_enh_fifo_full(tx_enh_fifo_full),
	.tx_enh_fifo_pfull(tx_enh_fifo_pfull),
	.tx_enh_fifo_empty(tx_enh_fifo_empty),
	.tx_enh_fifo_pempty(tx_enh_fifo_pempty),
	.rx_enh_fifo_rd_en(rx_enh_fifo_rd_en),
	.rx_enh_data_valid(rx_enh_data_valid),
	.rx_enh_fifo_full(rx_enh_fifo_full),
	.rx_enh_fifo_pfull(rx_enh_fifo_pfull),
	.rx_enh_fifo_empty(rx_enh_fifo_empty),
	.rx_enh_fifo_pempty(rx_enh_fifo_pempty),
//	.rx_enh_fifo_align_clr(rx_enh_fifo_align_clr),
	.rx_enh_blk_lock(rx_enh_blk_lock),
//	.rx_enh_fifo_del(rx_enh_fifo_del),
//	.rx_enh_fifo_insert(rx_enh_fifo_insert),
	.rx_enh_highber(rx_enh_highber),
//	.rx_pma_div_clkout(rx_pma_div_clkout),
//	.tx_pma_div_clkout(tx_pma_div_clkout),

    .init_start(init_start),
    .init_done(init_done),

	// management port
	.prmgmt_ctrl_clk(Clk_100),
	.prmgmt_cmd(prmgmt_cmd),
	.prmgmt_addr(prmgmt_addr),
	.prmgmt_din(prmgmt_din),
	.prmgmt_dout(prmgmt_dout),
  	.prmgmt_freeze(prmgmt_freeze),
    .prmgmt_arst(prmgmt_arst),
  	.prmgmt_ram_ena(prmgmt_ram_ena),
    .prmgmt_fatal_err(prmgmt_fatal_err)
);

assign g2b_GPIO_a    = 5'b0;
assign g2b_GPIO_b    = 5'b0;
assign g2b_I2C0_scl  = 1'b0;
assign g2b_I2C0_sda  = 1'b0;
assign g2b_I2C0_rstn = 1'b0;
assign g2b_I2C1_scl  = 1'b0;
assign g2b_I2C1_sda  = 1'b0;
assign g2b_I2C1_rstn = 1'b0;

assign oen_GPIO_a    = 5'b0;
assign oen_GPIO_b    = 5'b0;
assign oen_I2C0_scl  = 1'b0;
assign oen_I2C0_sda  = 1'b0;
assign oen_I2C0_rstn = 1'b0;
assign oen_I2C1_scl  = 1'b0;
assign oen_I2C1_sda  = 1'b0;
assign oen_I2C1_rstn = 1'b0;

(* noprune *) reg [4:0] b2g_GPIO_a_q;
(* noprune *) reg [4:0] b2g_GPIO_b_q;
(* noprune *) reg       b2g_I2C0_scl_q;
(* noprune *) reg       b2g_I2C0_sda_q;
(* noprune *) reg       b2g_I2C0_rstn_q;
(* noprune *) reg       b2g_I2C1_scl_q;
(* noprune *) reg       b2g_I2C1_sda_q;
(* noprune *) reg       b2g_I2C1_rstn_q;

always @(posedge Clk_100)
begin
    b2g_GPIO_a_q    <= b2g_GPIO_a    ;
    b2g_GPIO_b_q    <= b2g_GPIO_b    ;
    b2g_I2C0_scl_q  <= b2g_I2C0_scl  ;
    b2g_I2C0_sda_q  <= b2g_I2C0_sda  ;
    b2g_I2C0_rstn_q <= b2g_I2C0_rstn ;
    b2g_I2C1_scl_q  <= b2g_I2C1_scl  ;
    b2g_I2C1_sda_q  <= b2g_I2C1_sda  ;
    b2g_I2C1_rstn_q <= b2g_I2C1_rstn ;
end
`endif // INCLUDE_ETHERNET

endmodule
