// (C) 1992-2016 Altera Corporation. All rights reserved.                         
// Your use of Altera Corporation's design tools, logic functions and other       
// software and tools, and its AMPP partner logic functions, and any output       
// files any of the foregoing (including device programming or simulation         
// files), and any associated documentation or information are expressly subject  
// to the terms and conditions of the Altera Program License Subscription         
// Agreement, Altera MegaCore Function License Agreement, or other applicable     
// license agreement, including, without limitation, that your use is for the     
// sole purpose of programming logic devices manufactured by Altera and sold by   
// Altera or its authorized distributors.  Please refer to the applicable         
// agreement for further details.                                                 
    

module freeze_wrapper(

  input			freeze,

  //////// board ports //////////
  input	          board_kernel_clk_clk,
  input	          board_kernel_clk2x_clk,
  input        		board_kernel_reset_reset_n,
  output [0:0]   	board_kernel_irq_irq,
  output          board_kernel_cra_waitrequest,
  output [63:0]		board_kernel_cra_readdata,
  output         	board_kernel_cra_readdatavalid,
  input   [0:0]   board_kernel_cra_burstcount,
  input  [63:0]   board_kernel_cra_writedata,
  input  [29:0]   board_kernel_cra_address,
  input         	board_kernel_cra_write,
  input         	board_kernel_cra_read,
  input   [7:0]  	board_kernel_cra_byteenable,
  input         	board_kernel_cra_debugaccess,
  input           board_avmm_r_waitrequest,
  input  [511:0] 	board_avmm_r_readdata,
  input          	board_avmm_r_readdatavalid,
  output [4:0]   	board_avmm_r_burstcount,
  output [511:0]	board_avmm_r_writedata,
  output [63:0]  	board_avmm_r_address,
  output        	board_avmm_r_write,
  output         	board_avmm_r_read,
  output [63:0]  	board_avmm_r_byteenable,
  output         	board_avmm_r_debugaccess,
  input          	board_avmm_w_waitrequest,
  input  [511:0] 	board_avmm_w_readdata,
  input          	board_avmm_w_readdatavalid,
  output [4:0]   	board_avmm_w_burstcount,
  output [511:0] 	board_avmm_w_writedata,
  output [63:0]  	board_avmm_w_address,
  output         	board_avmm_w_write,
  output         	board_avmm_w_read,
  output [63:0]  	board_avmm_w_byteenable,
  output         	board_avmm_w_debugaccess
);

reg  [7:0]    kernel_reset_count;                            // counter to release RESETn and FREEZE in the proper sequence
reg  [2:0]    freeze_kernel_clk;                             // metastability hardening to being FREEZE signal onto the kernel clock
reg         	kernel_system_clock_reset_reset_reset_n;       // RESETn signal must be held de-asserted during PR, then assert when PR is done
reg           pr_freeze_reg;                                 // internal copy of the FREEZE signal, held asserted longer than the input FREEZE signal to allow PR region to be reset

// control signals out of the Kernel that must be held inactive during PR (controlled by the FREEZE signal)
wire         	kernel_system_kernel_irq_irq;
wire         	kernel_system_kernel_cra_waitrequest;
wire         	kernel_system_kernel_cra_readdatavalid;
wire         	kernel_system_avmm_r_read;
wire         	kernel_system_avmm_w_write;

// capture the freeze signal onto the kernel clock domain
always @( posedge board_kernel_clk_clk or negedge board_kernel_reset_reset_n)  
begin
   if ( board_kernel_reset_reset_n == 1'b0 ) begin
     freeze_kernel_clk[0] <= 1'b0;
     freeze_kernel_clk[1] <= 1'b0;
     freeze_kernel_clk[2] <= 1'b0;
   end else begin
     freeze_kernel_clk[0] <= freeze;
     freeze_kernel_clk[1] <= freeze_kernel_clk[0];
     freeze_kernel_clk[2] <= freeze_kernel_clk[1];
   end
end

// circuitry to implement freeze/reset requirements on the GLOBAL kernel RESETn signal
// During PR (when freeze input is asserted), hold RESETn HIGH
// After PR is done, continue to hold control outputs from this block in the frozen (inactive) state while RESETn is driven low
// Finally, release the internal freeze signal and then release the kernel RESETn signal
always @( posedge board_kernel_clk_clk or negedge board_kernel_reset_reset_n )
begin
   if ( board_kernel_reset_reset_n == 1'b0 ) begin
      kernel_reset_count <= 8'h00;
      kernel_system_clock_reset_reset_reset_n <= 1'b0;
      pr_freeze_reg       <= 1'b0;
   end else begin

      if ( freeze_kernel_clk[2] == 1'b1 ) begin
         kernel_reset_count <= 8'h00;
      end else if (kernel_reset_count != 8'hFF) begin
         kernel_reset_count <= kernel_reset_count + 1'b1;
      end else begin
         kernel_reset_count <= kernel_reset_count;
      end
      
      if ( (freeze_kernel_clk[2] == 1'b1) || (kernel_reset_count == 8'hFF) ) begin
         kernel_system_clock_reset_reset_reset_n <= 1'b1;
      end else if ( kernel_reset_count >= 8'h40 ) begin
         kernel_system_clock_reset_reset_reset_n <= 1'b0;
      end
      
      if ( freeze_kernel_clk[2] == 1'b1 || (!kernel_reset_count[7] && pr_freeze_reg) ) begin
          pr_freeze_reg       <= 1'b1;
      end else begin
          pr_freeze_reg       <= 1'b0;
      end

   end
end


// hold all control outputs from the Kernel region inactive during PR
// Signals in the PR region will toggle at random during PR, we must protect external circuitry from being corrupted
assign board_kernel_irq_irq	            = pr_freeze_reg ? 1'b0:kernel_system_kernel_irq_irq;
assign board_kernel_cra_waitrequest    	= pr_freeze_reg ? 1'b1:kernel_system_kernel_cra_waitrequest;
assign board_kernel_cra_readdatavalid   = pr_freeze_reg ? 1'b0:kernel_system_kernel_cra_readdatavalid;
assign board_avmm_r_read			          = pr_freeze_reg ? 1'b0:kernel_system_avmm_r_read;
assign board_avmm_w_write			          = pr_freeze_reg ? 1'b0:kernel_system_avmm_w_write;

// Signals not used
assign board_avmm_r_write	              = 1'b0;
assign board_avmm_r_debugaccess			    = 1'b0;
assign board_avmm_r_writedata           = 512'b0;
assign board_avmm_r_byteenable          = 64'b0;
assign board_avmm_w_read			          = 1'b0;
assign board_avmm_w_debugaccess			    = 1'b0;

//assign board_avmm_w_address[63:48]      = 16'b0;
//assign board_avmm_r_address[63:48]      = 16'b0;

//=======================================================
//  kernel_system instantiation
//=======================================================
kernel_wrapper kernel_wrapper_inst (
  .clock_reset_clk(board_kernel_clk_clk),
  .clock_reset2x_clk(board_kernel_clk2x_clk),
  .clock_reset_reset_reset_n(kernel_system_clock_reset_reset_reset_n),
  .kernel_irq_irq(kernel_system_kernel_irq_irq),
  .kernel_cra_waitrequest(kernel_system_kernel_cra_waitrequest),
  .kernel_cra_readdata(board_kernel_cra_readdata),
  .kernel_cra_readdatavalid(kernel_system_kernel_cra_readdatavalid),
  .kernel_cra_burstcount(board_kernel_cra_burstcount),
  .kernel_cra_writedata(board_kernel_cra_writedata),
  .kernel_cra_address(board_kernel_cra_address),
  .kernel_cra_write(board_kernel_cra_write),
  .kernel_cra_read(board_kernel_cra_read),
  .kernel_cra_byteenable(board_kernel_cra_byteenable),
  .kernel_cra_debugaccess(board_kernel_cra_debugaccess),
  .avmm_r_waitrequest(board_avmm_r_waitrequest),
  .avmm_r_readdata(board_avmm_r_readdata),
  .avmm_r_readdatavalid(board_avmm_r_readdatavalid),
  .avmm_r_burstcount(board_avmm_r_burstcount),
  .avmm_r_address(board_avmm_r_address),
  .avmm_r_read(kernel_system_avmm_r_read),
  .avmm_w_waitrequest(board_avmm_w_waitrequest),
  .avmm_w_burstcount(board_avmm_w_burstcount),
  .avmm_w_writedata(board_avmm_w_writedata),
  .avmm_w_address(board_avmm_w_address),
  .avmm_w_write(kernel_system_avmm_w_write),
  .avmm_w_byteenable(board_avmm_w_byteenable)
);

endmodule
