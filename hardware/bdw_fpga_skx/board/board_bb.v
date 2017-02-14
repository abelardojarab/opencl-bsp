
module board (
	avmm_r_slave_waitrequest,
	avmm_r_slave_readdata,
	avmm_r_slave_readdatavalid,
	avmm_r_slave_burstcount,
	avmm_r_slave_writedata,
	avmm_r_slave_address,
	avmm_r_slave_write,
	avmm_r_slave_read,
	avmm_r_slave_byteenable,
	avmm_r_slave_debugaccess,
	avmm_w_slave_waitrequest,
	avmm_w_slave_readdata,
	avmm_w_slave_readdatavalid,
	avmm_w_slave_burstcount,
	avmm_w_slave_writedata,
	avmm_w_slave_address,
	avmm_w_slave_write,
	avmm_w_slave_read,
	avmm_w_slave_byteenable,
	avmm_w_slave_debugaccess,
	bridge_reset_reset,
	ci0_InitDone,
	ci0_virtual_access,
	ci0_tx_c0_almostfull,
	ci0_rx_c0_header,
	ci0_rx_c0_data,
	ci0_rx_c0_wrvalid,
	ci0_rx_c0_rdvalid,
	ci0_rx_c0_ugvalid,
	ci0_rx_c0_mmiordvalid,
	ci0_rx_c0_mmiowrvalid,
	ci0_tx_c1_almostfull,
	ci0_rx_c1_header,
	ci0_rx_c1_wrvalid,
	ci0_rx_c1_irvalid,
	ci0_tx_c0_header,
	ci0_tx_c0_rdvalid,
	ci0_tx_c1_header,
	ci0_tx_c1_data,
	ci0_tx_c1_wrvalid,
	ci0_tx_c1_irvalid,
	ci0_tx_c1_byteen,
	ci0_tx_c2_header,
	ci0_tx_c2_rdvalid,
	ci0_tx_c2_data,
	ci0_nohazards_rd,
	ci0_nohazards_wr_full,
	ci0_nohazards_wr_all,
	clk_400_clk,
	global_reset_reset_n,
	kernel_clk_clk,
	kernel_cra_waitrequest,
	kernel_cra_readdata,
	kernel_cra_readdatavalid,
	kernel_cra_burstcount,
	kernel_cra_writedata,
	kernel_cra_address,
	kernel_cra_write,
	kernel_cra_read,
	kernel_cra_byteenable,
	kernel_cra_debugaccess,
	kernel_irq_irq,
	kernel_reset_reset_n,
	psl_clk_clk,
	kernel_clk_in_clk);	

	output		avmm_r_slave_waitrequest;
	output	[511:0]	avmm_r_slave_readdata;
	output		avmm_r_slave_readdatavalid;
	input	[4:0]	avmm_r_slave_burstcount;
	input	[511:0]	avmm_r_slave_writedata;
	input	[63:0]	avmm_r_slave_address;
	input		avmm_r_slave_write;
	input		avmm_r_slave_read;
	input	[63:0]	avmm_r_slave_byteenable;
	input		avmm_r_slave_debugaccess;
	output		avmm_w_slave_waitrequest;
	output	[511:0]	avmm_w_slave_readdata;
	output		avmm_w_slave_readdatavalid;
	input	[4:0]	avmm_w_slave_burstcount;
	input	[511:0]	avmm_w_slave_writedata;
	input	[63:0]	avmm_w_slave_address;
	input		avmm_w_slave_write;
	input		avmm_w_slave_read;
	input	[63:0]	avmm_w_slave_byteenable;
	input		avmm_w_slave_debugaccess;
	input		bridge_reset_reset;
	input		ci0_InitDone;
	input		ci0_virtual_access;
	input		ci0_tx_c0_almostfull;
	input	[27:0]	ci0_rx_c0_header;
	input	[511:0]	ci0_rx_c0_data;
	input		ci0_rx_c0_wrvalid;
	input		ci0_rx_c0_rdvalid;
	input		ci0_rx_c0_ugvalid;
	input		ci0_rx_c0_mmiordvalid;
	input		ci0_rx_c0_mmiowrvalid;
	input		ci0_tx_c1_almostfull;
	input	[27:0]	ci0_rx_c1_header;
	input		ci0_rx_c1_wrvalid;
	input		ci0_rx_c1_irvalid;
	output	[98:0]	ci0_tx_c0_header;
	output		ci0_tx_c0_rdvalid;
	output	[98:0]	ci0_tx_c1_header;
	output	[511:0]	ci0_tx_c1_data;
	output		ci0_tx_c1_wrvalid;
	output		ci0_tx_c1_irvalid;
	output	[63:0]	ci0_tx_c1_byteen;
	output	[8:0]	ci0_tx_c2_header;
	output		ci0_tx_c2_rdvalid;
	output	[63:0]	ci0_tx_c2_data;
	output		ci0_nohazards_rd;
	output		ci0_nohazards_wr_full;
	output		ci0_nohazards_wr_all;
	input		clk_400_clk;
	input		global_reset_reset_n;
	output		kernel_clk_clk;
	input		kernel_cra_waitrequest;
	input	[63:0]	kernel_cra_readdata;
	input		kernel_cra_readdatavalid;
	output	[0:0]	kernel_cra_burstcount;
	output	[63:0]	kernel_cra_writedata;
	output	[29:0]	kernel_cra_address;
	output		kernel_cra_write;
	output		kernel_cra_read;
	output	[7:0]	kernel_cra_byteenable;
	output		kernel_cra_debugaccess;
	input	[0:0]	kernel_irq_irq;
	output		kernel_reset_reset_n;
	input		psl_clk_clk;
	input		kernel_clk_in_clk;
endmodule
