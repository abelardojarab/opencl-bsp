// system.v

// Top level module of OpenCL for MCP

`timescale 1 ps / 1 ps
module system (
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
    output wire         kernel_clk,
    input wire          bridge_reset_reset,
    input  wire         opencl_freeze,
	  output wire  nohazards_rd  ,     
  output wire nohazards_wr_full,  
  output wire nohazards_wr_all 
	);

	wire          board_kernel_cra_waitrequest;                    // kernel_system:kernel_cra_waitrequest -> board:kernel_cra_waitrequest
	wire   [63:0] board_kernel_cra_readdata;                       // kernel_system:kernel_cra_readdata -> board:kernel_cra_readdata
	wire          board_kernel_cra_debugaccess;                    // board:kernel_cra_debugaccess -> kernel_system:kernel_cra_debugaccess
	wire   [29:0] board_kernel_cra_address;                        // board:kernel_cra_address -> kernel_system:kernel_cra_address
	wire          board_kernel_cra_read;                           // board:kernel_cra_read -> kernel_system:kernel_cra_read
	wire    [7:0] board_kernel_cra_byteenable;                     // board:kernel_cra_byteenable -> kernel_system:kernel_cra_byteenable
	wire          board_kernel_cra_readdatavalid;                  // kernel_system:kernel_cra_readdatavalid -> board:kernel_cra_readdatavalid
	wire   [63:0] board_kernel_cra_writedata;                      // board:kernel_cra_writedata -> kernel_system:kernel_cra_writedata
	wire          board_kernel_cra_write;                          // board:kernel_cra_write -> kernel_system:kernel_cra_write
	wire    [0:0] board_kernel_cra_burstcount;                     // board:kernel_cra_burstcount -> kernel_system:kernel_cra_burstcount
	wire          board_kernel_clk_clk;                            // board:kernel_clk_clk -> [irq_mapper:clk, kernel_system:clock_reset_clk, mm_interconnect_0:board_kernel_clk_clk, mm_interconnect_1:board_kernel_clk_clk, mm_interconnect_2:board_kernel_clk_clk, rr_arb:clk, rst_controller:clk]
	wire          board_kernel_clk2x_clk;                          // board:kernel_clk2x_clk -> kernel_system:clock_reset2x_clk
	wire          board_kernel_reset_reset;                        // board:kernel_reset_reset_n -> [kernel_system:clock_reset_reset_reset_n, mm_interconnect_0:rr_arb_reset_reset_bridge_in_reset_reset, mm_interconnect_1:kernel_system_clock_reset_reset_reset_bridge_in_reset_reset, mm_interconnect_2:kernel_system_clock_reset_reset_reset_bridge_in_reset_reset, rr_arb:reset]
	wire          kernel_system_avmm_r_waitrequest;                // mm_interconnect_1:kernel_system_avmm_r_waitrequest -> kernel_system:avmm_r_waitrequest
	wire  [511:0] kernel_system_avmm_r_readdata;                   // mm_interconnect_1:kernel_system_avmm_r_readdata -> kernel_system:avmm_r_readdata
	wire          kernel_system_avmm_r_debugaccess;                // kernel_system:avmm_r_debugaccess -> mm_interconnect_1:kernel_system_avmm_r_debugaccess
	wire   [63:0] kernel_system_avmm_r_address;                    // kernel_system:avmm_r_address -> mm_interconnect_1:kernel_system_avmm_r_address
	wire          kernel_system_avmm_r_read;                       // kernel_system:avmm_r_read -> mm_interconnect_1:kernel_system_avmm_r_read
	wire   [63:0] kernel_system_avmm_r_byteenable;                 // kernel_system:avmm_r_byteenable -> mm_interconnect_1:kernel_system_avmm_r_byteenable
	wire          kernel_system_avmm_r_readdatavalid;              // mm_interconnect_1:kernel_system_avmm_r_readdatavalid -> kernel_system:avmm_r_readdatavalid
	wire  [511:0] kernel_system_avmm_r_writedata;                  // kernel_system:avmm_r_writedata -> mm_interconnect_1:kernel_system_avmm_r_writedata
	wire          kernel_system_avmm_r_write;                      // kernel_system:avmm_r_write -> mm_interconnect_1:kernel_system_avmm_r_write
	wire    [4:0] kernel_system_avmm_r_burstcount;                 // kernel_system:avmm_r_burstcount -> mm_interconnect_1:kernel_system_avmm_r_burstcount
	wire          kernel_system_avmm_w_waitrequest;                // mm_interconnect_2:kernel_system_avmm_w_waitrequest -> kernel_system:avmm_w_waitrequest
	wire  [511:0] kernel_system_avmm_w_readdata;                   // mm_interconnect_2:kernel_system_avmm_w_readdata -> kernel_system:avmm_w_readdata
	wire          kernel_system_avmm_w_debugaccess;                // kernel_system:avmm_w_debugaccess -> mm_interconnect_2:kernel_system_avmm_w_debugaccess
	wire   [63:0] kernel_system_avmm_w_address;                    // kernel_system:avmm_w_address -> mm_interconnect_2:kernel_system_avmm_w_address
	wire          kernel_system_avmm_w_read;                       // kernel_system:avmm_w_read -> mm_interconnect_2:kernel_system_avmm_w_read
	wire   [63:0] kernel_system_avmm_w_byteenable;                 // kernel_system:avmm_w_byteenable -> mm_interconnect_2:kernel_system_avmm_w_byteenable
	wire          kernel_system_avmm_w_readdatavalid;              // mm_interconnect_2:kernel_system_avmm_w_readdatavalid -> kernel_system:avmm_w_readdatavalid
	wire  [511:0] kernel_system_avmm_w_writedata;                  // kernel_system:avmm_w_writedata -> mm_interconnect_2:kernel_system_avmm_w_writedata
	wire          kernel_system_avmm_w_write;                      // kernel_system:avmm_w_write -> mm_interconnect_2:kernel_system_avmm_w_write
	wire    [4:0] kernel_system_avmm_w_burstcount;                 // kernel_system:avmm_w_burstcount -> mm_interconnect_2:kernel_system_avmm_w_burstcount
	wire          irq_mapper_receiver0_irq;                        // kernel_system:kernel_irq_irq -> irq_mapper:receiver0_irq
	wire    [0:0] board_kernel_irq_irq;                            // irq_mapper:sender_irq -> board:kernel_irq_irq
	wire          rst_controller_reset_out_reset;                  // rst_controller:reset_out -> [irq_mapper:reset, mm_interconnect_0:board_global_reset_reset_bridge_in_reset_reset, mm_interconnect_0:board_qpi_slave_translator_reset_reset_bridge_in_reset_reset]
  
  assign kernel_clk = board_kernel_clk_clk;
	
	
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
    .fake_snoop_ready                   (),                                                //   fake_snoop.ready
    .fake_snoop_valid                   (),                                                //             .valid
    .fake_snoop_data                    (),                                                //             .data
    .global_reset_reset_n               (global_reset_reset_n),                            // global_reset.reset_n
    .bridge_reset_reset                 (bridge_reset_reset),
    .kernel_clk_clk                     (board_kernel_clk_clk),                            //   kernel_clk.clk
    .kernel_clk2x_clk                   (board_kernel_clk2x_clk),                          // kernel_clk2x.clk
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
    .kernel_reset_reset_n               (board_kernel_reset_reset),                        // kernel_reset.reset_n
    .psl_clk_clk                        (clk_200_clk),                                     //      psl_clk.clk
    .avmm_r_slave_waitrequest           (kernel_system_avmm_r_waitrequest),
    .avmm_r_slave_readdata              (kernel_system_avmm_r_readdata),
    .avmm_r_slave_readdatavalid         (kernel_system_avmm_r_readdatavalid),
    .avmm_r_slave_burstcount            (kernel_system_avmm_r_burstcount),
    .avmm_r_slave_writedata             (kernel_system_avmm_r_writedata),
    .avmm_r_slave_address               (kernel_system_avmm_r_address),
    .avmm_r_slave_write                 (kernel_system_avmm_r_write),
    .avmm_r_slave_read                  (kernel_system_avmm_r_read),
    .avmm_r_slave_byteenable            (kernel_system_avmm_r_byteenable),
    .avmm_r_slave_debugaccess           (kernel_system_avmm_r_debugaccess),
    .avmm_w_slave_waitrequest           (kernel_system_avmm_w_waitrequest),
    .avmm_w_slave_readdata              (kernel_system_avmm_w_readdata),
    .avmm_w_slave_readdatavalid         (kernel_system_avmm_w_readdatavalid),
    .avmm_w_slave_burstcount            (kernel_system_avmm_w_burstcount),
    .avmm_w_slave_writedata             (kernel_system_avmm_w_writedata),
    .avmm_w_slave_address               (kernel_system_avmm_w_address),
    .avmm_w_slave_write                 (kernel_system_avmm_w_write),
    .avmm_w_slave_read                  (kernel_system_avmm_w_read),
    .avmm_w_slave_byteenable            (kernel_system_avmm_w_byteenable),
    .avmm_w_slave_debugaccess           (kernel_system_avmm_w_debugaccess),
	.ci0_nohazards_rd  (nohazards_rd),   
    .ci0_nohazards_wr_full (nohazards_wr_full),
    .ci0_nohazards_wr_all (nohazards_wr_all)
	);

  
	freeze_wrapper freeze_wrapper_inst (
    .freeze                     	  (opencl_freeze),
		.board_kernel_clk_clk       	  (board_kernel_clk_clk),
		.board_kernel_clk2x_clk     	  (board_kernel_clk2x_clk),
		.board_kernel_reset_reset_n 	  (board_kernel_reset_reset),
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
		.board_avmm_r_waitrequest       (kernel_system_avmm_r_waitrequest),
		.board_avmm_r_readdata          (kernel_system_avmm_r_readdata),
		.board_avmm_r_readdatavalid     (kernel_system_avmm_r_readdatavalid),
		.board_avmm_r_burstcount        (kernel_system_avmm_r_burstcount),
		.board_avmm_r_writedata         (kernel_system_avmm_r_writedata),
		.board_avmm_r_address           (kernel_system_avmm_r_address),
		.board_avmm_r_write             (kernel_system_avmm_r_write),
		.board_avmm_r_read              (kernel_system_avmm_r_read),
		.board_avmm_r_byteenable        (kernel_system_avmm_r_byteenable),
		.board_avmm_r_debugaccess       (kernel_system_avmm_r_debugaccess),
		.board_avmm_w_waitrequest       (kernel_system_avmm_w_waitrequest),
		.board_avmm_w_readdata          (kernel_system_avmm_w_readdata),
		.board_avmm_w_readdatavalid     (kernel_system_avmm_w_readdatavalid),
		.board_avmm_w_burstcount        (kernel_system_avmm_w_burstcount),
		.board_avmm_w_writedata         (kernel_system_avmm_w_writedata),
		.board_avmm_w_address           (kernel_system_avmm_w_address),
		.board_avmm_w_write             (kernel_system_avmm_w_write),
		.board_avmm_w_read              (kernel_system_avmm_w_read),
		.board_avmm_w_byteenable        (kernel_system_avmm_w_byteenable),
		.board_avmm_w_debugaccess       (kernel_system_avmm_w_debugaccess)
	);


endmodule
