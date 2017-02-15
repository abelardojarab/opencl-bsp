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


 
module cci_requester #(
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
	output reg [73:0] tx_c0_header,
	output reg tx_c0_rdvalid,
	input tx_c0_almostfull,
	input [27:0] rx_c1_header,
	input rx_c1_wrvalid,
	output reg [73:0] tx_c1_header,
	output reg [511:0] tx_c1_data,
	output reg tx_c1_wrvalid,
	input tx_c1_almostfull,
  output reg  [63:0] tx_c1_byteen,
	input [57:0] avmm_address,
  input virtual_access,
  input [3:0] request_type,
	input [63:0] avmm_byteenable,
  input [3:0] avmm_burstcount,
	input avmm_write,
	input [511:0] avmm_writedata,
	input avmm_read,
	output avmm_waitrequest,
	input [PEND_REQS_LOG2-1-1:0] read_tag,
	input read_tag_ready,
	output read_tag_valid,
	input [PEND_REQS_LOG2-1-1:0] write_tag,
	input write_tag_ready,
	output write_tag_valid,
  output transaction_pending,
  input     use_bridge_mapping_r,
  input     use_bridge_mapping_w   ,
  input     use_vl_r,
  input     use_vl_w ,
  input     use_vh_r,
  input     use_vh_w,
  input     use_rdline_i ,
  input     use_wrline_i                
  
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
localparam A_WIDTH   = 42;//32 + 26; // 32 bits for CCI-S, extra 26 bits for CCI-E
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
localparam BURST_S = TYPE_E+1;
localparam BURST_E = TYPE_E+4;
localparam SOP = BURST_E+1;
localparam VECTOR_S  = 0;
localparam VECTOR_E  = SOP;


 `define CCIP
 `ifdef CCIP
localparam ADDR_LO_S  = 16;
localparam ADDR_LO_E  = 57;
localparam REQ_TYPE_S  = 64;
localparam REQ_TYPE_E  = 67;

 `else
 localparam VIRT_ADDR  = 66;
localparam ADDR_LO_S  = 14;
localparam ADDR_LO_E  = 45;
localparam ADDR_HI_S  = 67;
localparam ADDR_HI_E  = 92;
localparam REQ_TYPE_S  = 52;
localparam REQ_TYPE_E  = 55;
 
 `endif

wire [VECTOR_E:VECTOR_S] fifo_in;
wire [VECTOR_E:VECTOR_S] fifo_out;




wire cam_match;
reg [VECTOR_E:VECTOR_S] buffer_pre0;
reg [VECTOR_E:VECTOR_S] buffer_pre1;
reg [VECTOR_E:VECTOR_S] buffer_pre2;
reg [VECTOR_E:VECTOR_S] buffer_pre3;
reg [VECTOR_E:VECTOR_S] buffer_r0;
reg [VECTOR_E:VECTOR_S] buffer_r1;

reg valid_pre0;
reg valid_pre1;
reg valid_pre2;
reg valid_pre3;
reg valid_r0;
reg valid_r1;




wire fifo_wr;
wire fifo_rd;
wire fifo_full;
wire fifo_empty;
wire [PEND_REQS_LOG2-1:0] tag;


reg [63:0] cl_read_req_avalon;
reg [63:0] cl_read_rsp_avalon;
reg [63:0] cl_read_req_cci;
reg [63:0] cl_read_req_fifo;
  always @ (posedge clk) begin
  if ((reset_n == 1'b0)) begin
    cl_read_req_avalon <= 0;
    cl_read_rsp_avalon <= 0;
    cl_read_req_cci <= 0;
    cl_read_req_fifo <= 0;
  end else
    if (avmm_read && !avmm_waitrequest)  cl_read_req_avalon <=    cl_read_req_avalon + (avmm_burstcount ? avmm_burstcount : 1) ;
        
    if ( rx_c0_rdvalid  )  cl_read_rsp_avalon <=    cl_read_rsp_avalon + 1 ;
    
    if ( tx_c0_rdvalid ) cl_read_req_cci <= cl_read_req_cci + tx_c1_header[69:68] + 1;
    if ( fifo_wr && ~tag[PEND_REQS_LOG2-1] && !fifo_full) cl_read_req_fifo <= cl_read_req_fifo + fifo_in[BURST_E:BURST_S];
  end




reg [3:0] burst_cycle;
reg [A_WIDTH-1:0] burst_addr;
reg [3:0] burst_length;
reg     [2:0] burst_state;
parameter BURST_IDLE = 0, //no burst in progress
BURST_WRITE = 1, //write burst in progress
BURST_WRITE_BREAK = 2, //write burst in progress, not valid cci burst so break into 1CLs 
BURST_READ_BREAK = 3;  //read burst in progress, not valid cci burst so break into 1CLs 

reg [PEND_REQS_LOG2-1-1:0] burst_tag;
wire [A_WIDTH-1:0] burst_addr_inc ;
wire bursting;
wire burst_eop;
wire write_sop ;
wire write_sop_burst;
wire write_accepted;
wire read_accepted;

//for when we generate a new read request when breaking up a read burst
wire internal_read_accepted ;

wire write_sop_invalid;
wire read_sop_invalid;

wire break_write_burst;
wire break_read_burst;
wire invalid_burst;
wire fifo_sop;
wire [3:0] fifo_burst_count;
  always @ (posedge clk) begin
  if ((reset_n == 1'b0)) begin
      burst_state <= BURST_IDLE;
      burst_cycle <= 0;
      burst_addr <= 0;
      burst_length <= 0;
      burst_tag <= 0;
  end else
  case (burst_state)
     BURST_IDLE: begin
        burst_state <= write_sop_invalid ? BURST_WRITE_BREAK : 
        write_sop_burst ? BURST_WRITE : 
        read_sop_invalid ? BURST_READ_BREAK : 
        BURST_IDLE ;
        
        burst_cycle  <= 1  ;
        burst_addr <= avmm_address;
        burst_length <= avmm_burstcount ;
        burst_tag <= write_accepted ?  write_tag : read_tag;  
        end
     BURST_WRITE: begin
        burst_state <= burst_eop ? BURST_IDLE : BURST_WRITE ;
        burst_cycle  <=  write_accepted ? burst_cycle + 1 : burst_cycle ;
        end
     BURST_WRITE_BREAK: begin
        burst_state <= burst_eop ? BURST_IDLE : BURST_WRITE_BREAK ;
        burst_cycle  <=  write_accepted ? burst_cycle + 1 : burst_cycle ;
        end
     BURST_READ_BREAK: begin
        burst_state <= internal_read_accepted && ((burst_cycle + 1) == burst_length) ? BURST_IDLE : BURST_READ_BREAK ;
        burst_cycle  <=  internal_read_accepted ? burst_cycle + 1 : burst_cycle ;
          end
  endcase
  end



assign bursting = (burst_state != BURST_IDLE) &&  (burst_state != BURST_READ_BREAK);
assign break_write_burst =  (burst_state == BURST_WRITE_BREAK);
assign break_read_burst =  (burst_state == BURST_READ_BREAK);
assign write_accepted = (avmm_write && !avmm_waitrequest);
assign read_accepted = (avmm_read && !avmm_waitrequest);
assign internal_read_accepted = (break_read_burst && !fifo_full && read_tag_ready);
assign sop = !bursting && (write_accepted || read_accepted )  ;

assign invalid_burst = ((avmm_burstcount == 2'b11) || ((avmm_burstcount == 3'b100 ) && |avmm_address[1:0] ) || ((avmm_burstcount == 3'b10 ) && avmm_address[0] )  );
assign write_sop_burst = sop && avmm_write && (avmm_burstcount > 1'b1);
assign write_sop_invalid = sop && avmm_write && invalid_burst;
assign read_sop_invalid = sop && (avmm_read && invalid_burst) ;  
  

assign burst_eop = bursting && write_accepted && ((burst_cycle + 1) == burst_length);
assign burst_addr_inc = burst_addr + burst_cycle;

assign fifo_burst_count = read_sop_invalid || (write_sop_invalid) || break_write_burst ||  break_read_burst ? 1'b1 :   avmm_burstcount  ; 
assign fifo_sop = sop || ( break_write_burst && write_accepted) || ( break_read_burst);






assign tag = (avmm_write && ~break_read_burst) ? {1'b1,(burst_state == BURST_WRITE)? burst_tag :write_tag}:{1'b0,read_tag};

assign fifo_in          = {fifo_sop, fifo_burst_count,request_type,virtual_access,tag,avmm_byteenable, bursting || break_read_burst ? burst_addr_inc: avmm_address[41:0],avmm_writedata};
assign fifo_wr          = ((avmm_write | avmm_read) & ~avmm_waitrequest  ) | internal_read_accepted ;
assign fifo_rd          = (~fifo_empty & ~(tx_c1_almostfull | tx_c0_almostfull));





assign avmm_waitrequest = fifo_full | (avmm_write && ~write_tag_ready) | (avmm_read && ~read_tag_ready) | break_read_burst;
assign read_tag_valid   = ( avmm_read  && ~avmm_waitrequest ) || (internal_read_accepted);
assign write_tag_valid  = avmm_write && ~avmm_waitrequest && !(burst_state == BURST_WRITE);


wire [A_WIDTH-1:0] addr_r1 = buffer_r1[ADDR_E:ADDR_S]  ;


reg [1:0] vc_sel;
reg [1:0] vc_sel_vh;
wire [4:0] addr_sel;
assign addr_sel = addr_r1 >> 2;


always_comb
case (addr_sel)
  5'b00000 : vc_sel = 2'b01;
  5'b00001 : vc_sel = 2'b10;
  5'b00010 : vc_sel = 2'b11;
  5'b00011 : vc_sel = 2'b01;
  5'b00100 : vc_sel = 2'b10;
  5'b00101 : vc_sel = 2'b11;
  5'b00110 : vc_sel = 2'b01;
  5'b00111 : vc_sel = 2'b10; 
  5'b01000 : vc_sel = 2'b11;
  5'b01001 : vc_sel = 2'b01;
  5'b01010 : vc_sel = 2'b10;
  5'b01011 : vc_sel = 2'b11;
  5'b01100 : vc_sel = 2'b01;
  5'b01101 : vc_sel = 2'b10;
  5'b01110 : vc_sel = 2'b11;
  5'b01111 : vc_sel = 2'b01; 
  5'b10000 : vc_sel = 2'b10;
  5'b10001 : vc_sel = 2'b11;
  5'b10010 : vc_sel = 2'b01;
  5'b10011 : vc_sel = 2'b10;
  5'b10100 : vc_sel = 2'b11;
  5'b10101 : vc_sel = 2'b01;
  5'b10110 : vc_sel = 2'b10;
  5'b10111 : vc_sel = 2'b11; 
  5'b11000 : vc_sel = 2'b01;
  5'b11001 : vc_sel = 2'b10;
  5'b11010 : vc_sel = 2'b11;
  5'b11011 : vc_sel = 2'b01;
  5'b11100 : vc_sel = 2'b10;
  5'b11101 : vc_sel = 2'b11;
  5'b11110 : vc_sel = 2'b10;
  5'b11111 : vc_sel = 2'b11;   
endcase

always_comb
case (addr_sel[0])
  1'b0 : vc_sel_vh = 2'b10;
  1'b1 : vc_sel_vh = 2'b11;
endcase


/*
reg bursting;
reg [2:0] burst_cycle;
reg burst_sop;
  input [3:0] avmm_burstcount,
	input avmm_write,
	input [511:0] avmm_writedata,
	input avmm_read,

*/









always @(posedge clk or negedge reset_n) begin
	if (~reset_n) begin
		tx_c0_rdvalid <= 1'b0;
		tx_c1_wrvalid <= 1'b0;
		valid_r0      <= 1'b0;
		valid_r1      <= 1'b0;
    valid_pre1     <= 1'b0;

	end else begin

		tx_c0_header  <= 99'b0;
		tx_c0_rdvalid <= 1'b0;
		tx_c1_header  <= 99'b0;
		//tx_c1_data    <= {D_WIDTH{1'b0}};
		tx_c1_wrvalid <= 1'b0;
    
    tx_c1_data    <= buffer_r1[DATA_E:DATA_S];
		

    buffer_pre0 <= fifo_out;
    buffer_r0     <= buffer_pre0;
    buffer_r1     <= buffer_r0;
  

    valid_pre0     <= fifo_rd;
    valid_r0      <= valid_pre0;
    valid_r1      <= valid_r0;


		if (valid_r1) begin

			// CCI Type
			tx_c0_rdvalid <= ~buffer_r1[TAG_E];
			tx_c1_wrvalid <=  buffer_r1[TAG_E];
			
			// Read Header Info
			tx_c0_header[PEND_REQS_LOG2-1:0]  <= buffer_r1[TAG_E:TAG_S];
			tx_c0_header[ADDR_LO_E:ADDR_LO_S]  <= buffer_r1[ADDR_E:ADDR_S];
			//tx_c0_header[ADDR_HI_E:ADDR_HI_S]  <= buffer_r1[ADDR_E:ADDR_E-25]; // CCI-E extra address
			tx_c0_header[REQ_TYPE_E:REQ_TYPE_S]  <=  RD_LINE_I;//  todo - re-enable//use_rdline_i ? RD_LINE_I: RD_LINE_S; //~full_write_r1 ? RD_LINE_S: buffer_r1[TYPE_E:TYPE_S];
			//tx_c0_header[VIRT_ADDR]     <= buffer_r1[VA_B];
            tx_c0_header[73:72]     <=  use_bridge_mapping_r ? vc_sel : use_vl_r ? 2'b1 : use_vh_r ? vc_sel_vh : 2'b0 ;
			tx_c0_header[71]     <= buffer_r1[SOP];
      
            tx_c0_header[69:68] <= buffer_r1[BURST_E:BURST_S]-1'b1;
      
			// Write Header Info
			tx_c1_header[PEND_REQS_LOG2-1:0]  <= buffer_r1[TAG_E:TAG_S];
			tx_c1_header[ADDR_LO_E:ADDR_LO_S]  <= buffer_r1[ADDR_E:ADDR_S];
			//tx_c1_header[ADDR_HI_E:ADDR_HI_S]  <= buffer_r1[ADDR_E:ADDR_E-25]; // CCI-E extra address
			tx_c1_header[REQ_TYPE_E:REQ_TYPE_S]  <= WR_THRU ; // todo clean upuse_wrline_i ? WR_THRU: WR_LINE; // buffer_r1[TYPE_E:TYPE_S]; //WR_LINE;
			//tx_c1_header[VIRT_ADDR]     <= buffer_r1[VA_B];
			tx_c1_header[71]     <= buffer_r1[SOP];
			tx_c1_header[73:72]     <=  use_bridge_mapping_w ? vc_sel : use_vl_w ? 2'b1 : use_vh_w ? vc_sel_vh : 2'b0 ;
			tx_c1_header[69:68]  <= buffer_r1[BURST_E:BURST_S]-1'b1;                 

							
			tx_c1_byteen =      buffer_r1[BYTEEN_E:BYTEEN_S];             
			// Data
	
		end
		
	end
end


wire valid_out;
acl_data_fifo	dfifo_component (
			.clock (clk),
			.data_in  (fifo_in),
			.stall_in (~fifo_rd),
			.valid_in (fifo_wr),
			.valid_out (valid_out),
			.stall_out  (fifo_full),
			.data_out     (fifo_out),
			.resetn (reset_n));
defparam
	dfifo_component.IMPL = "shift_reg",
	dfifo_component.DEPTH = 8,
	dfifo_component.DATA_WIDTH  = VECTOR_E+1;



assign fifo_empty = ~valid_out;


endmodule

