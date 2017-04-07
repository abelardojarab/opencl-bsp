// (C) 2001-2015 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program // (C) 2001-2015 Altera Corporation. All rights reserved.
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


 
module write_granter #(
	parameter PEND_REQS = 16,
	parameter PEND_REQS_LOG2 = 4
	)(
	input clk,
	input reset_n,
	input [23:0] rx_c0_header,
	input rx_c0_wrvalid,
	input [23:0] rx_c1_header,
	input rx_c1_wrvalid,
	output [PEND_REQS_LOG2-1:0] write_tag,
	output write_tag_ready,
	input write_tag_valid,
	output write_pending
	);

reg  fifo_init_done;
reg  fifo_wr;
wire fifo_rd;
wire fifo_empty;
wire fifo_full;
wire [PEND_REQS_LOG2-1:0] fifo_out;
reg  [PEND_REQS_LOG2-1:0] fifo_in;
reg  bfifo_wr;
wire bfifo_empty;
wire bfifo_full;
wire [PEND_REQS_LOG2-1:0] bfifo_out;
reg  [PEND_REQS_LOG2-1:0] bfifo_in;
reg [PEND_REQS_LOG2+3:0] write_tag_reg;
reg [PEND_REQS_LOG2+3:0] pending_reg;
assign write_tag_ready = 1'b1;
assign write_tag = write_tag_reg;
assign write_pending = |pending_reg;

reg write_tag_valid_reg;
reg rx_c1_wrvalid_reg;

always @(posedge clk or negedge reset_n) begin
	// on reset initialize all control signals (reorder buffer indices and valids)
	if (reset_n == 1'b0) begin

    pending_reg <= 0;
    write_tag_reg <= 0;
	
    write_tag_valid_reg <= 0;
    rx_c1_wrvalid_reg <= 0;
	
	end
	else begin
		// set valid to the "next" reorder buffer valid unless otherwise specified

		// When a cacheline read is returned
		
		    write_tag_valid_reg <= write_tag_valid;
    rx_c1_wrvalid_reg <= rx_c1_wrvalid;
    write_tag_reg <= write_tag_valid ? write_tag_reg + 1 : write_tag_reg;
     pending_reg <= pending_reg + write_tag_valid_reg - rx_c1_wrvalid_reg;
	end
end


/*
always @(posedge clk or negedge reset_n) begin
	if (~reset_n) begin
		fifo_init_done     <= 1'b0;
		fifo_wr            <= 1'b1;
		fifo_in            <= {PEND_REQS_LOG2{1'b0}};
		bfifo_wr            <= 1'b0;
		bfifo_in            <= {PEND_REQS_LOG2{1'b0}};
	end
	else begin
		fifo_wr     <= 1'b0;
		bfifo_wr    <= 1'b0;
		
		if (rx_c1_wrvalid) begin
			fifo_wr <= 1'b1;
			fifo_in <= rx_c1_header[PEND_REQS_LOG2-1:0];
		end
		else if (~bfifo_empty) begin
			fifo_wr <= 1'b1;
			fifo_in <= bfifo_out;
		end
		
		if (rx_c0_wrvalid) begin
			bfifo_wr <= 1'b1;
			bfifo_in <= rx_c0_header[PEND_REQS_LOG2-1:0];
		end
	
		if (~fifo_init_done) begin
			fifo_in <= fifo_in + {{PEND_REQS_LOG2-1{1'b0}},1'b1};
			fifo_wr <= 1'b1;
			if (&fifo_in) begin
				fifo_wr        <= 1'b0;
				fifo_init_done <= 1'b1;
			end
		end	
	end
end

scfifo	wrtoken_main (
			.clock (clk),
			.data (fifo_in),
			.rdreq (fifo_rd),
			.wrreq (fifo_wr),
			.empty (fifo_empty),
			.full (fifo_full),
			.q (fifo_out),
			.usedw (),
			.aclr (~reset_n),
			.almost_empty (),
			.almost_full (),
			.sclr (~reset_n));
defparam
	wrtoken_main.add_ram_output_register = "ON",
	wrtoken_main.intended_device_family = "Stratix V",
	wrtoken_main.lpm_numwords = PEND_REQS,
	wrtoken_main.lpm_showahead = "ON",
	wrtoken_main.lpm_type = "scfifo",
	wrtoken_main.lpm_width = PEND_REQS_LOG2,
	wrtoken_main.lpm_widthu = PEND_REQS_LOG2,
	wrtoken_main.overflow_checking = "ON",
	wrtoken_main.underflow_checking = "ON",
	wrtoken_main.use_eab = "OFF";
	
scfifo	wrtoken_backup (
			.clock (clk),
			.data (bfifo_in),
			.rdreq (~bfifo_empty && ~rx_c1_wrvalid),
			.wrreq (bfifo_wr),
			.empty (bfifo_empty),
			.full (bfifo_full),
			.q (bfifo_out),
			.usedw (),
			.aclr (~reset_n),
			.almost_empty (),
			.almost_full (),
			.sclr (~reset_n));
defparam
	wrtoken_backup.add_ram_output_register = "ON",
	wrtoken_backup.intended_device_family = "Stratix V",
	wrtoken_backup.lpm_numwords = PEND_REQS,
	wrtoken_backup.lpm_showahead = "ON",
	wrtoken_backup.lpm_type = "scfifo",
	wrtoken_backup.lpm_width = PEND_REQS_LOG2,
	wrtoken_backup.lpm_widthu = PEND_REQS_LOG2,
	wrtoken_backup.overflow_checking = "ON",
	wrtoken_backup.underflow_checking = "ON",
	wrtoken_backup.use_eab = "OFF";

*/

endmodule
