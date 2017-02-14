// (C) 2001-2015 Altera Corporation. All rights reserved.
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


module parallel_match_s5 #(
	parameter DATA_WIDTH = 32,
	parameter ADDR_1HOT = 16,
	parameter ADDR_WIDTH = 4
	)(
	input clk,
	input rst,
	input [ADDR_WIDTH-1:0] waddr,
	input [DATA_WIDTH-1:0] wdata,
	input [DATA_WIDTH-1:0] wcare,
	input wena,
	input [DATA_WIDTH-1:0] lookup_data,
	input lookup_data_valid,
	input lookup_ena,
	output reg match,
	output reg [ADDR_1HOT-1:0] match_addr_1h,
	output reg [ADDR_WIDTH-1:0] match_addr
	);
 

wire [ADDR_1HOT-1:0] match_lines;
wire [ADDR_1HOT-1:0] word_wena;
reg  [ADDR_1HOT-1:0] waddr_dec;
reg zero_time_match;

always @(*) begin
    waddr_dec = 0;
    waddr_dec[waddr] = 1'b1;
end

assign word_wena = waddr_dec & {ADDR_1HOT{wena}};

// writing "all don't care" disables the word.
wire wused = |wcare /*synthesis keep*/;

// storage and match cells
genvar i;
generate 
  for (i=0; i<ADDR_1HOT; i=i+1)
  begin : cw
    reg_cam_cell c (
		.clk(clk),
		.rst(rst),
		.wdata(wdata),
		.wcare(wcare),
		.wused(wused),
		.wena(word_wena[i]),
		.lookup_data(lookup_data),
		.lookup_ena(lookup_ena),
		.zero_time_match(zero_time_match),
		.match(match_lines[i])
    );
    defparam c.DATA_WIDTH = DATA_WIDTH; 
  end
endgenerate

wire [ADDR_WIDTH-1:0] onehot;
reg lookup_data_valid_r0 = 1'b0;
reg lookup_ena_r0 = 1'b0;
always @(posedge clk) begin 
	if (rst) begin zero_time_match <= 1'b0; end
  lookup_ena_r0 <= lookup_ena;
	if (lookup_ena) begin
		lookup_data_valid_r0 <= lookup_data_valid;
		match                <= |match_lines & lookup_data_valid_r0;
		match_addr           <= onehot;
		match_addr_1h        <= match_lines;
	end
	
	// This is a patch fix for zero time matches..
	// This does not take into account partial don't cares..
	if (lookup_ena && (lookup_data == wdata)) zero_time_match <= 1'b1;
  if (lookup_ena && (lookup_data != wdata)) zero_time_match <= 1'b0;
end
	

genvar k,j;
generate
	for (j=0; j<ADDR_WIDTH; j=j+1)
	begin : jl
		wire [ADDR_1HOT-1:0] tmp_mask;
		for (k=0; k<ADDR_1HOT; k=k+1)
		begin : il
			assign tmp_mask[k] = k[j];
		end	
		assign onehot[j] = |(tmp_mask & match_lines);
	end
endgenerate



// match encoder


endmodule


module reg_cam_cell (
	clk,rst,
	wdata,wcare,wused,wena,
	lookup_data,lookup_ena,zero_time_match,match
);

parameter DATA_WIDTH = 32;

input clk,rst;
input [DATA_WIDTH-1:0] wdata, wcare;
input wused,wena;

input [DATA_WIDTH-1:0] lookup_data;
input lookup_ena;
input zero_time_match;
output match;
reg match_int;
reg wena_r1;
reg cell_used;

// Storage cells
reg [DATA_WIDTH - 1 : 0] data;
reg [DATA_WIDTH - 1 : 0] care;
always @(posedge clk) begin
  if (rst) begin
	cell_used <= 1'b0;
	data <= {DATA_WIDTH{1'b0}};
	care <= {DATA_WIDTH{1'b0}};
	wena_r1 <= 1'b0;
  end else begin
	if (wena) begin
	   cell_used <= wused;
	   data <= wdata;
       care <= wcare;
	end
  if(lookup_ena) begin
	wena_r1 <= wena;
  end
  end
end

// Ternary match
wire [DATA_WIDTH-1:0] bit_match;
genvar i;
generate 
  for (i=0; i<DATA_WIDTH; i=i+1)
  begin : bmt
    assign bit_match[i] = !care[i] | !(data[i] ^ lookup_data[i]);
  end
endgenerate

always @(posedge clk) begin
  if (rst) match_int <= 1'b0;
  else if (lookup_ena) match_int <= (& bit_match) & cell_used;
end

assign match = match_int | (zero_time_match & wena_r1);

endmodule

