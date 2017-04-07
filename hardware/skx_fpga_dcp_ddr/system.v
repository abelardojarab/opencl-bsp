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

		.cci_interface_slave_unused_waitrequest   (),   // cci_interface_slave_unused.waitrequest
		.cci_interface_slave_unused_readdata      (),      //                           .readdata
		.cci_interface_slave_unused_readdatavalid (), //                           .readdatavalid
		.cci_interface_slave_unused_burstcount    (),    //                           .burstcount
		.cci_interface_slave_unused_writedata     (),     //                           .writedata
		.cci_interface_slave_unused_address       (),       //                           .address
		.cci_interface_slave_unused_write         (1'b0),         //                           .write
		.cci_interface_slave_unused_read          (1'b0),          //                           .read
		.cci_interface_slave_unused_byteenable    (),    //                           .byteenable
		.cci_interface_slave_unused_debugaccess   (),   //                           .debugaccess
    
	.ci0_nohazards_rd  (nohazards_rd),   
    .ci0_nohazards_wr_full (nohazards_wr_full),
    .ci0_nohazards_wr_all (nohazards_wr_all),
	.kernel_clk_in_clk(kernel_clk)
	);



endmodule
