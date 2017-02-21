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


module parallel_match #(
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
  input [64-1:0] lookup_ena_parallel,
  input [ADDR_1HOT-1:0] in_use,
	output reg match,
	output reg [ADDR_1HOT-1:0] match_addr_1h,
	output reg [ADDR_WIDTH-1:0] match_addr
	);
 

wire [ADDR_1HOT-1:0] match_lines;
reg [ADDR_1HOT-1:0] match_lines_r;
reg [ADDR_1HOT-1:0] word_wena;
reg  [ADDR_1HOT-1:0] waddr_dec;
reg zero_time_match;

always @(*) begin
    waddr_dec = 0;
    waddr_dec[waddr] = 1'b1;
end

//assign word_wena = waddr_dec & {ADDR_1HOT{wena}};

//todo account pr 1 cycle delay elsewhere
reg [DATA_WIDTH-1:0] wdata_r;
reg [DATA_WIDTH-1:0] wcare_r;

always @(posedge clk) begin 
	word_wena <= waddr_dec & {ADDR_1HOT{wena}};
  wdata_r <= wdata;
  wcare_r <= wcare;
end

// writing "all don't care" disables the word.
wire wused = |wcare_r /*synthesis keep*/;

// storage and match cells
genvar i;
generate 
  for (i=0; i<ADDR_1HOT; i=i+1)
  begin : cw
    reg_cam_cell c (
		.clk(clk),
		.rst(rst),
		.wdata(wdata_r),
		.wcare(wcare_r),
		.wused(wused),
		.wena(word_wena[i]),
    .in_use(in_use[i]),
		.lookup_data(lookup_data),
		.lookup_ena(lookup_ena_parallel[i%64]),
		.zero_time_match(zero_time_match),
		.match(match_lines[i])
    );
    defparam c.DATA_WIDTH = DATA_WIDTH; 
  end
endgenerate

wire [ADDR_WIDTH-1:0] onehot;
reg lookup_data_valid_r0 = 1'b0;
reg lookup_data_valid_r1 = 1'b0;
reg lookup_data_valid_r2 = 1'b0;
reg lookup_data_valid_r3 = 1'b0;
reg lookup_ena_r0 = 1'b0;
always @(posedge clk) begin 
	if (rst) begin zero_time_match <= 1'b0; end
  lookup_ena_r0 <= lookup_ena;
	if (lookup_ena) begin
		lookup_data_valid_r0 <= lookup_data_valid;
    lookup_data_valid_r1 <= lookup_data_valid_r0;
    lookup_data_valid_r2 <= lookup_data_valid_r1;
    lookup_data_valid_r3 <= lookup_data_valid_r2;
    match_lines_r <= match_lines;
		match                <= |match_lines_r & lookup_data_valid_r2;
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
		assign onehot[j] = |(tmp_mask & match_lines_r);
	end
endgenerate



// match encoder


endmodule


module reg_cam_cell (
	clk,rst,
	wdata,wcare,wused,wena, in_use,
	lookup_data,lookup_ena,zero_time_match,match
);

parameter DATA_WIDTH = 32;

input clk,rst;
input [DATA_WIDTH-1:0] wdata, wcare;
input wused,wena;
input in_use;
input [DATA_WIDTH-1:0] lookup_data;
input lookup_ena;
input zero_time_match;
output match;
reg match_int;
reg wena_r1;
reg wena_r2;
reg ztm_r;
reg in_use_r1;
reg in_use_r2;
reg in_use_r3;
// Storage cells
reg [DATA_WIDTH - 1 : 0] data;
always @(posedge clk) begin
  if (rst) begin
	data <= {DATA_WIDTH{1'b0}};
	wena_r1 <= 1'b0;
  wena_r2 <= 1'b0;
  in_use_r1 <= 1'b0;
  in_use_r2 <= 1'b0;
  ztm_r <= 1'b0;
  end else begin
	if (wena) begin
	   data <= wdata;
	end
  if(lookup_ena) begin
	wena_r1 <= wena;
  wena_r2 <= wena_r1;
  in_use_r1 <= in_use;
  in_use_r2 <= in_use_r1;
  in_use_r3 <= in_use_r2;
  ztm_r <= zero_time_match;
  end
  end
end

// Ternary match
reg [DATA_WIDTH-1:0] bit_match;
genvar i;
generate 
  for (i=0; i<DATA_WIDTH; i=i+1)
  begin : bmt
		always @(posedge clk) begin
			bit_match[i] <= lookup_ena ? !(data[i] ^ lookup_data[i]) : bit_match[i]; //needto account for this cycle elsewhere
		end
  end
endgenerate

always @(posedge clk) begin
  if (rst) match_int <= 1'b0;
  else if (lookup_ena) match_int <= (& bit_match);
end

assign match = (match_int && in_use_r3) | (ztm_r & wena_r1) ;

endmodule

