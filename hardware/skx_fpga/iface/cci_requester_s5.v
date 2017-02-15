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


 
module cci_requester_s5 #(
	parameter PEND_REQS = 32,
	parameter PEND_REQS_LOG2 = 5,
  parameter TYPE_WIDTH = 4
	)(
	input clk,
	input reset_n,
	
	input [27:0] rx_c0_header,
	input [511:0] rx_c0_data,
	input rx_c0_rdvalid,
	input rx_c0_wrvalid,
	output reg [98:0] tx_c0_header,
	output reg tx_c0_rdvalid,
	input tx_c0_almostfull,
	input [27:0] rx_c1_header,
	input rx_c1_wrvalid,
	output reg [98:0] tx_c1_header,
	output reg [511:0] tx_c1_data,
	output reg tx_c1_wrvalid,
	input tx_c1_almostfull,
	input [57:0] avmm_address,
  input virtual_access,
  input [3:0] request_type,
	input [63:0] avmm_byteenable,
	input avmm_write,
	input [511:0] avmm_writedata,
	input avmm_read,
	output avmm_waitrequest,
	input [PEND_REQS_LOG2-1-1:0] read_tag,
	input read_tag_ready,
	output read_tag_valid,
	input [PEND_REQS_LOG2-1-1:0] write_tag,
	input write_tag_ready,
	output write_tag_valid
	);


// These are reserved command encodings specified in CCI
localparam WR_THRU     = 4'h0;
localparam WR_LINE     = 4'h1;
localparam WR_FENCE    = 4'h4;
localparam RD_LINE_S   = 4'h1;
localparam RD_LINE_I   = 4'h0;
localparam RD_LINE_E   = 4'h1;
localparam INTERRUPT   = 4'h8;

// Vector definitions for slice calculations
// data widths
localparam D_WIDTH   = 512;
localparam A_WIDTH   = 32 + 26; // 32 bits for CCI-S, extra 26 bits for CCI-E
localparam BE_WIDTH  = 64;
//slice pointers
localparam DATA_S    = 0;
localparam DATA_E    = D_WIDTH - 1;
localparam ADDR_S    = DATA_E  + 1;
localparam ADDR_E    = DATA_E  + A_WIDTH;
localparam BYTEEN_S  = ADDR_E  + 1;
localparam BYTEEN_E  = ADDR_E  + BE_WIDTH;
localparam TAG_S     = BYTEEN_E + 1;
localparam TAG_E     = BYTEEN_E + PEND_REQS_LOG2;
localparam VA_B = TAG_E+1;
localparam TYPE_S = VA_B+1;
localparam TYPE_E = VA_B+TYPE_WIDTH;
localparam VECTOR_S  = 0;
localparam VECTOR_E  = TYPE_E;


localparam VIRT_ADDR  = 98;
localparam ADDR_LO_S  = 16;
localparam ADDR_LO_E  = 57;
localparam ADDR_HI_S  = 74;
localparam ADDR_HI_E  = 91;
localparam REQ_TYPE_S  = 64;
localparam REQ_TYPE_E  = 67;




wire [VECTOR_E:VECTOR_S] fifo_in;
wire [VECTOR_E:VECTOR_S] fifo_out;

wire cam_match;

reg [VECTOR_E:VECTOR_S] buffer_r0;
reg [VECTOR_E:VECTOR_S] buffer_r1;
reg [VECTOR_E:VECTOR_S] buffer_r2;
reg valid_r0;
reg valid_r1;
reg valid_r2;
reg stall;
reg [2:0] stall_src;


reg [PEND_REQS_LOG2-1:0] stall_addr_0;
reg [PEND_REQS_LOG2-1:0] stall_addr_1;
reg [PEND_REQS_LOG2-1:0] stall_addr_2;


wire [PEND_REQS_LOG2-1:0] cam_match_addr;
wire [PEND_REQS-1:0] cam_match_addr_1h;

wire fifo_wr;
wire fifo_rd;
wire fifo_full;
wire fifo_empty;
reg  [PEND_REQS_LOG2-1:0]  waddr = 4'b0;
reg  [A_WIDTH-1:0] wdata = {A_WIDTH{1'b0}};
reg         wena = 1'b0;
wire [A_WIDTH-1:0] lookup_data;
wire fast_stop,stop_n;
wire [PEND_REQS_LOG2-1:0] tag;
reg [PEND_REQS-1:0] in_use;
reg full_write_r0,full_write_r1;
reg [BE_WIDTH-1:0] byteenable_save;
reg rmw_save;
reg rmw_hold;
reg rmw_start1;
reg rmw_start2;
reg [D_WIDTH-1:0] rmw_buffer1;
reg [D_WIDTH-1:0] rmw_buffer2;
reg [D_WIDTH-1:0] rmw_buffer3;
reg [PEND_REQS_LOG2-1:0] rmw_line1;
reg [PEND_REQS_LOG2-1:0] rmw_line2;
reg [PEND_REQS_LOG2-1:0] rmw_line3;
reg [A_WIDTH-1:0] rmw_address3;
reg               rmw_vaddress3;
reg in_use_stop;

reg pipe_01_eq;
reg pipe_02_eq;
reg pipe_12_eq;
wire [(BE_WIDTH+A_WIDTH+D_WIDTH+1)-1:0] rmw_ram;

assign tag = (avmm_write) ? {1'b1,write_tag}:{1'b0,read_tag};

assign fifo_in          = {request_type,virtual_access,tag,avmm_byteenable,avmm_address,avmm_writedata};
assign fifo_wr          = (avmm_write | avmm_read) & ~avmm_waitrequest;
assign fifo_rd          = (~fifo_empty & ~(tx_c1_almostfull | tx_c0_almostfull) & stop_n);
assign fast_stop        = cam_match && ~stall && valid_r1 && |(cam_match_addr_1h&in_use);//&& in_use_stop;
assign stop_n           = ~fast_stop && ~stall && ~rmw_hold;
assign avmm_waitrequest = fifo_full | (avmm_write && ~write_tag_ready) | (avmm_read && ~read_tag_ready);
assign read_tag_valid   = avmm_read  && ~avmm_waitrequest;
assign write_tag_valid  = avmm_write && ~avmm_waitrequest;


wire [A_WIDTH-1:0] addr_fifo_out = fifo_out[ADDR_E:ADDR_S] /* synthesis keep */;
wire [A_WIDTH-1:0] addr_r0 = buffer_r0[ADDR_E:ADDR_S] /* synthesis keep */;
wire [A_WIDTH-1:0] addr_r1 = buffer_r1[ADDR_E:ADDR_S] /* synthesis keep */;
wire [A_WIDTH-1:0] addr_r2 = buffer_r2[ADDR_E:ADDR_S] /* synthesis keep */;

always @(posedge clk or negedge reset_n) begin
	if (~reset_n) begin
		stall         <= 1'b0;
		wena          <= 1'b0;
		in_use        <= {PEND_REQS{1'h0}};
		tx_c0_rdvalid <= 1'b0;
		tx_c1_wrvalid <= 1'b0;
		valid_r0      <= 1'b0;
		valid_r1      <= 1'b0;
		valid_r2      <= 1'b0;
		full_write_r0 <= 1'b0;
		full_write_r1 <= 1'b0;
		rmw_save      <= 1'b0;
		rmw_hold      <= 1'b0;
		rmw_start1    <= 1'b0;
		rmw_start2    <= 1'b0;
		pipe_01_eq    <= 1'b0;
		pipe_02_eq    <= 1'b0;
    pipe_12_eq    <= 1'b0;
		in_use_stop   <= 1'b0;
    
    stall_src <= 3'b0;
	end else begin
		rmw_save      <= 1'b0;
		rmw_hold      <= 1'b0;
		rmw_start1    <= 1'b0;
		rmw_start2    <= 1'b0;
		wena          <= 1'b0;
		wdata         <= {A_WIDTH{1'b0}};
		tx_c0_header  <= 99'b0;
		tx_c0_rdvalid <= 1'b0;
		tx_c1_header  <= 99'b0;
		tx_c1_data    <= {D_WIDTH{1'b0}};
		tx_c1_wrvalid <= 1'b0;
		pipe_01_eq    <= stall ? pipe_01_eq : 1'b0;
		pipe_02_eq    <= 1'b0;
    pipe_12_eq    <= 1'b0;
		

		if (stop_n) begin
		
			if ((fifo_out[BYTEEN_E:BYTEEN_S] == {BE_WIDTH{1'b1}}) || ~fifo_out[TAG_E] ) full_write_r0 <= 1'b1;
			else full_write_r0 <= 1'b0;
		
			buffer_r0     <= fifo_out;
			buffer_r1     <= buffer_r0;
      buffer_r2     <= buffer_r1;
			valid_r0      <= fifo_rd;
			valid_r1      <= valid_r0;
			valid_r2      <= valid_r1;
			full_write_r1 <= full_write_r0;
		end
		
		if (rx_c0_rdvalid && ~rx_c0_header[12] && (rx_c0_header[PEND_REQS_LOG2-1:0] == buffer_r0[TAG_E:TAG_S])) in_use_stop <= 1'b0;
		else if (rx_c0_wrvalid && (rx_c0_header[PEND_REQS_LOG2-1:0] == buffer_r0[TAG_E:TAG_S])) in_use_stop <= 1'b0;
		else if (rx_c1_wrvalid && (rx_c1_header[PEND_REQS_LOG2-1:0] == buffer_r0[TAG_E:TAG_S])) in_use_stop <= 1'b0;
		else in_use_stop <= in_use[buffer_r0[TAG_E:TAG_S]];
		
		if (rx_c0_rdvalid & ~rx_c0_header[12]) in_use[rx_c0_header[PEND_REQS_LOG2-1:0]] <= 0;
		if (rx_c0_wrvalid)                     in_use[rx_c0_header[PEND_REQS_LOG2-1:0]] <= 0;
		if (rx_c1_wrvalid)                     in_use[rx_c1_header[PEND_REQS_LOG2-1:0]] <= 0;
		
		

		if ((addr_fifo_out == addr_r0) && ~stall) pipe_01_eq    <= 1'b1;
		if ((addr_fifo_out == addr_r1) && ~stall) pipe_02_eq    <= 1'b1;
    if ((addr_r0 == addr_r1) && ~stall) pipe_12_eq    <= 1'b1;
    
    if(stall) begin 
      //upon returning from a stall, we may need to stall immediately the next cycle
      // a: pipe_01_eq goes high on the cycle the stall went high
      //          therefore need to trigger a stall on the address of r1
      // b: pipe_01_eq goes high on the cycle *after* the stall went high (as there was new data last cycle) 
      //          therefore need to trigger a stall on r1 still
      pipe_01_eq <= pipe_01_eq || (addr_r0 == addr_r1);
      pipe_02_eq <= pipe_02_eq;
    end
		
		if (pipe_01_eq && valid_r0 && valid_r1 && ~stall) begin
			stall      <= 1'b1;
			stall_addr_0 <= buffer_r1[TAG_E:TAG_S];
      stall_src[0] <= 1'b1;
		end
		if (pipe_02_eq && valid_r0 && valid_r2 && ~stall) begin
			stall      <= 1'b1;
			stall_addr_1 <= buffer_r2[TAG_E:TAG_S];
      stall_src[1] <= 1'b1;
		end
		
		if (fast_stop) begin 
			stall      <= 1'b1;
			stall_addr_2 <= cam_match_addr;
      stall_src[2] <= 1'b1;
		end
		
		
		if ( stall_src[0] &&  (in_use[stall_addr_0] == 1'b0)) begin
      stall_src[0] <= 1'b0;
    end
		if ( stall_src[1] &&  (in_use[stall_addr_1] == 1'b0)) begin
      stall_src[1] <= 1'b0;
    end
    if ( stall_src[2] &&  (in_use[stall_addr_2] == 1'b0)) begin
      stall_src[2] <= 1'b0;
    end
    
		if ((stall == 1'b1) && (stall_src == 3'b0) ) begin
			stall <= 1'b0;
			wena  <= 1'b1;
			wdata <= addr_r1;
			waddr <= buffer_r1[TAG_E:TAG_S];
		end
		
		if (stop_n && valid_r1) begin
			wena  <= 1'b1;
			wdata <= addr_r1;
			waddr <= buffer_r1[TAG_E:TAG_S];
			in_use[buffer_r1[TAG_E:TAG_S]] <= 1'b1;
			
			byteenable_save <= buffer_r1[BYTEEN_E:BYTEEN_S];
			
			// CCI Type
			tx_c0_rdvalid <= ~buffer_r1[TAG_E];
			tx_c1_wrvalid <=  buffer_r1[TAG_E];
			
			// Read Header Info
			tx_c0_header[PEND_REQS_LOG2-1:0]  <= buffer_r1[TAG_E:TAG_S];
			tx_c0_header[ADDR_LO_E:ADDR_LO_S]  <= buffer_r1[ADDR_S+41:ADDR_S];
			tx_c0_header[ADDR_HI_E:ADDR_HI_S]  <= buffer_r1[ADDR_E:ADDR_E-25]; // CCI-E extra address
			tx_c0_header[REQ_TYPE_E:REQ_TYPE_S]  <= ~full_write_r1 ? RD_LINE_S: buffer_r1[TYPE_E:TYPE_S];
			tx_c0_header[VIRT_ADDR]     <= buffer_r1[VA_B];
      tx_c0_header[73:72]     <= 2'b1;
			tx_c0_header[71]     <= 1'b1;
			// Write Header Info
			tx_c1_header[PEND_REQS_LOG2-1:0]  <= buffer_r1[TAG_E:TAG_S];
			tx_c1_header[ADDR_LO_E:ADDR_LO_S]  <= buffer_r1[ADDR_S+41:ADDR_S];
			tx_c1_header[ADDR_HI_E:ADDR_HI_S]  <= buffer_r1[ADDR_E:ADDR_E-25]; // CCI-E extra address
			tx_c1_header[REQ_TYPE_E:REQ_TYPE_S]  <= buffer_r1[TYPE_E:TYPE_S]; //WR_LINE;
			tx_c1_header[VIRT_ADDR]     <= buffer_r1[VA_B];
      tx_c1_header[71]     <= 1'b1;
      tx_c1_header[73:72]     <= 2'b1;
			// Data
			tx_c1_data    <= buffer_r1[DATA_E:DATA_S];
			
			if (~full_write_r1 && buffer_r1[VA_B]) begin
				tx_c0_rdvalid    <= 1'b1;
				tx_c1_wrvalid    <= 1'b0;
				tx_c0_header[12] <= 1'b1; // mark as special read
				rmw_save         <= 1'b1;
			end
			
		end
		
		if (rx_c0_rdvalid & ~rx_c0_header[12]) in_use[rx_c0_header[PEND_REQS_LOG2-1:0]] <= 0;
		if (rx_c0_wrvalid)                     in_use[rx_c0_header[PEND_REQS_LOG2-1:0]] <= 0;
		if (rx_c1_wrvalid)                     in_use[rx_c1_header[PEND_REQS_LOG2-1:0]] <= 0;
		if (rx_c0_rdvalid && rx_c0_header[12]) rmw_start1  <= 1'b1;
		
		rmw_buffer1   <= rx_c0_data;
		rmw_buffer2   <= rmw_buffer1;
		rmw_line1     <= rx_c0_header[PEND_REQS_LOG2-1:0];
		rmw_line2     <= rmw_line1;
		rmw_line3     <= rmw_line2;
		rmw_address3  <= rmw_ram[569:512];
		rmw_vaddress3 <= rmw_ram[634];
		rmw_start2    <= rmw_start1;
		rmw_hold      <= rmw_start2;
		
		if (rmw_hold) begin
			// Write Header Info
			tx_c1_header[PEND_REQS_LOG2-1:0]  <= rmw_line3;
			tx_c1_header[ADDR_LO_E:ADDR_LO_S]               <= rmw_address3[31:0];
			tx_c1_header[ADDR_HI_E:ADDR_HI_S]               <= rmw_address3[57:32]; // CCI-E extra address
			tx_c1_header[REQ_TYPE_E:REQ_TYPE_S]               <= WR_LINE;
			tx_c1_header[VIRT_ADDR]                  <= rmw_vaddress3;// virtual/physical address designator
			// Data
			tx_c1_data                        <= rmw_buffer3;
			tx_c1_wrvalid                     <= 1'b1;
		end
	end
end

genvar i;
generate
    for (i = 0; i < 64; i = i + 1) begin: rmw_coalesce
        always @(posedge clk) begin
			if (rmw_ram[BYTEEN_S+i]) begin
				rmw_buffer3[((i+1)*8)-1:i*8] <= rmw_ram[((i+1)*8)-1:i*8];
			end else begin
				rmw_buffer3[((i+1)*8)-1:i*8] <= rmw_buffer2[((i+1)*8)-1:i*8];
			end
		end
    end
endgenerate



altsyncram	ram_inst (
				.address_a (tx_c0_header[PEND_REQS_LOG2-2:0]),
				.address_b (rx_c0_header[PEND_REQS_LOG2-2:0]),
				.clock0 (clk),
				.data_a ({tx_c0_header[VIRT_ADDR],byteenable_save,tx_c0_header[ADDR_HI_E:ADDR_HI_S],tx_c0_header[ADDR_LO_E:ADDR_LO_S],tx_c1_data}),
				.wren_a (rmw_save),
				.q_b (rmw_ram),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b (635'b0),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		ram_inst.address_aclr_b = "NONE",
		ram_inst.address_reg_b = "CLOCK0",
		ram_inst.clock_enable_input_a = "BYPASS",
		ram_inst.clock_enable_input_b = "BYPASS",
		ram_inst.clock_enable_output_b = "BYPASS",
		ram_inst.intended_device_family = "STRATIX V",
		ram_inst.lpm_type = "altsyncram",
		ram_inst.numwords_a = PEND_REQS/2,
		ram_inst.numwords_b = PEND_REQS/2,
		ram_inst.operation_mode = "DUAL_PORT",
		ram_inst.outdata_aclr_b = "NONE",
		ram_inst.outdata_reg_b = "CLOCK0",
		ram_inst.power_up_uninitialized = "FALSE",
		ram_inst.read_during_write_mode_mixed_ports = "DONT_CARE",
		ram_inst.widthad_a = PEND_REQS_LOG2-1,
		ram_inst.widthad_b = PEND_REQS_LOG2-1,
		ram_inst.width_a = BE_WIDTH+A_WIDTH+D_WIDTH + 1,
		ram_inst.width_b = BE_WIDTH+A_WIDTH+D_WIDTH + 1,
		ram_inst.width_byteena_a = 1;


assign lookup_data = addr_fifo_out;

	parallel_match_s5 #(
		.DATA_WIDTH(A_WIDTH),
		.ADDR_1HOT(PEND_REQS),
		.ADDR_WIDTH(PEND_REQS_LOG2)
	) parallel_match_inst (
		.clk(clk),
		.rst(~reset_n),
		
		//program port
		.waddr(waddr),
		.wdata(wdata),
		.wcare({A_WIDTH{1'b1}}),
		.wena(wena),
		
		// lookup
		.lookup_data(lookup_data),
		.lookup_data_valid(fifo_rd),
		.lookup_ena(stop_n),
		// response
		.match(cam_match),
		.match_addr_1h(cam_match_addr_1h),
		.match_addr(cam_match_addr)
	);


scfifo	scfifo_component (
			.clock (clk),
			.data  (fifo_in),
			.rdreq (fifo_rd),
			.wrreq (fifo_wr),
			.empty (fifo_empty),
			.full  (fifo_full),
			.q     (fifo_out),
			.usedw (),
			.aclr  (~reset_n),
			.almost_empty (),
			.almost_full (),
			.sclr (~reset_n));
defparam
	scfifo_component.add_ram_output_register = "OFF",
	scfifo_component.intended_device_family = "STRATIX V",
	scfifo_component.lpm_numwords = 8,
	scfifo_component.lpm_showahead = "ON",
	scfifo_component.lpm_type = "scfifo",
	scfifo_component.lpm_width  = PEND_REQS_LOG2 + BE_WIDTH + A_WIDTH + D_WIDTH + TYPE_WIDTH + 1,
	scfifo_component.lpm_widthu = 3,
	scfifo_component.overflow_checking = "ON",
	scfifo_component.underflow_checking = "ON",
	scfifo_component.use_eab = "ON";



endmodule

