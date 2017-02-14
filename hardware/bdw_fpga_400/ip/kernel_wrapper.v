// kernel wrapper
// This is the PR boundary ports for kernel
// using kernel wrapper instead of kernel_system, since kernel_system is auto generated
// kernel_system introduces boundary ports that are not used, and in PR, it gets preserved

module kernel_wrapper(
  input	          clock_reset_clk,
  input	          clock_reset2x_clk,
  input        	  clock_reset_reset_reset_n,
  output          kernel_irq_irq,
  output          kernel_cra_waitrequest,
  output [63:0]   kernel_cra_readdata,
  output         	kernel_cra_readdatavalid,
  input   [0:0]   kernel_cra_burstcount,
  input  [63:0]   kernel_cra_writedata,
  input  [29:0]   kernel_cra_address,
  input           kernel_cra_write,
  input           kernel_cra_read,
  input   [7:0]  	kernel_cra_byteenable,
  input           kernel_cra_debugaccess,
  input           avmm_r_waitrequest,
  input  [511:0] 	avmm_r_readdata,
  input          	avmm_r_readdatavalid,
  output [4:0]   	avmm_r_burstcount,
  output [63:0]  	avmm_r_address,
  output         	avmm_r_read,
  input           avmm_w_waitrequest,
  output [4:0]   	avmm_w_burstcount,
  output [511:0] 	avmm_w_writedata,
  output [63:0]  	avmm_w_address,
  output         	avmm_w_write,
  output [63:0]  	avmm_w_byteenable
);

//=======================================================
//  kernel_system instantiation
//=======================================================
kernel_system kernel_system_inst (
  .clock_reset_clk(clock_reset_clk),
  .clock_reset2x_clk(clock_reset2x_clk),
  .clock_reset_reset_reset_n(clock_reset_reset_reset_n),
  .kernel_irq_irq(kernel_irq_irq),
  .kernel_cra_waitrequest(kernel_cra_waitrequest),
  .kernel_cra_readdata(kernel_cra_readdata),
  .kernel_cra_readdatavalid(kernel_cra_readdatavalid),
  .kernel_cra_burstcount(kernel_cra_burstcount),
  .kernel_cra_writedata(kernel_cra_writedata),
  .kernel_cra_address(kernel_cra_address),
  .kernel_cra_write(kernel_cra_write),
  .kernel_cra_read(kernel_cra_read),
  .kernel_cra_byteenable(kernel_cra_byteenable),
  .kernel_cra_debugaccess(kernel_cra_debugaccess),
  .avmm_r_waitrequest(avmm_r_waitrequest),
  .avmm_r_readdata(avmm_r_readdata),
  .avmm_r_readdatavalid(avmm_r_readdatavalid),
  .avmm_r_burstcount(avmm_r_burstcount),
  .avmm_r_address(avmm_r_address),
  .avmm_r_read(avmm_r_read),
  .avmm_w_waitrequest(avmm_w_waitrequest),
  .avmm_w_burstcount(avmm_w_burstcount),
  .avmm_w_writedata(avmm_w_writedata),
  .avmm_w_address(avmm_w_address),
  .avmm_w_write(avmm_w_write),
  .avmm_w_byteenable(avmm_w_byteenable),
  .avmm_r_writedata(),
  .avmm_r_write(),
  .avmm_r_byteenable(),
  .avmm_w_readdata(512'b0),
  .avmm_w_readdatavalid(1'b0),
  .avmm_w_read()
);

endmodule