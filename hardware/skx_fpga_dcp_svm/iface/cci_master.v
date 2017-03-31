// ***************************************************************************
// ***************************************************************************
// This module take a write only CCI transaction
// In a normal write, if the upper address bit is set it reads from that addr and write back to ssytem memory, which is polled

module cci_master #(parameter PEND_THRESH=1, ADDR_LMT=20, MDATA=14)
(
  input clk,
  input reset,
  //  originating cci cfg write master
  input  [31:0] cciconfig_address,
	input  cciconfig_write,
	input [31:0] cciconfig_writedata,
	output  cciconfig_waitrequest,
  
  
  //slave interface to cci system memory
  output wire [57:0] ccidata_address,
	output wire [63:0] ccidata_byteenable,
	output wire ccidata_write,
	output wire [511:0] ccidata_writedata,
	output wire ccidata_read,
	input wire [511:0] ccidata_readdata,
	input wire ccidata_readdatavalid,
	input wire ccidata_waitrequest,
    	
  
  //slave interface to kernel memory

  output [35:0] kernel_address,
	output kernel_write,
  output kernel_read,
	output [31:0] kernel_writedata,
  input  [31:0] kernel_readdata,
  input  kernel_readdatavalid,
	input  kernel_waitrequest,
    input [63:0] dsm_base
);

	//internal state machine to update id
	//---------------------------------------------------------
	// Write CSR Address Map ***** DO NOT MODIFY *****
	//---------------------------------------------------------
																				  // CSR Attribute - Comment
	localparam      CSR_AFU_DSM_BASEL    = 12'ha00;                 // WO - Lower 32-bits of AFU DSM base address. The lower 6-bbits are 4x00 since the address is cache aligned.
	localparam      CSR_AFU_DSM_BASEH    = 12'ha04;                 // WO - Upper 32-bits of AFU DSM base address.

  wire [63:0] cci_addr;
  //next lowest addr, cache aligned
  assign cci_addr = dsm_base[63:6]+1;

  localparam      STATE_IDLE                = 8'h00; 
  localparam      STATE_READ_REQUEST        = 8'h01; 
  localparam      STATE_READ_REQUESTED      = 8'h02; 
  localparam      STATE_WRITE_REQUEST       = 8'h04; 
  localparam      STATE_WRITE_SUBMITTED     = 8'h05; 


  wire kernel_write_req = cciconfig_write && (cciconfig_address > 32'h400);


  wire read_request = cciconfig_write && (cciconfig_address == 32'h200);

  reg [7:0] read_state;

  reg [31:0] read_counter; //used for polling

  reg [31:0] read_data;
  reg [31:0] read_addr;




  always @(posedge clk or posedge reset) begin
    if (reset) begin 
     read_data <= 0;
     read_state <= STATE_IDLE;
     read_addr <= 0;
     read_counter <=0;
    end else if (read_state == STATE_IDLE) begin
        // accept new requests 
        read_state  <= read_request ? STATE_READ_REQUEST : STATE_IDLE;
        read_addr   <= cciconfig_writedata;
    end else if (read_state == STATE_READ_REQUEST) begin
        read_state  <=  kernel_waitrequest ? STATE_READ_REQUEST : STATE_READ_REQUESTED;      
    end else if (read_state == STATE_READ_REQUESTED) begin
        read_state  <=  kernel_readdatavalid ? STATE_WRITE_REQUEST : STATE_READ_REQUESTED;   
        read_data <= kernel_readdata;
    end else if (read_state == STATE_WRITE_REQUEST) begin
        read_state  <=  ccidata_waitrequest ? STATE_WRITE_REQUEST : STATE_WRITE_SUBMITTED;        
    end else if (read_state == STATE_WRITE_SUBMITTED) begin
        read_state  <=  STATE_IDLE;        
        read_counter <= read_counter + 1'b1;
    end
  end
  wire read_in_progress = (read_state != STATE_IDLE);
  assign cciconfig_waitrequest = read_in_progress || kernel_waitrequest;
  
  assign kernel_address = read_in_progress ? read_addr[31:2] : cciconfig_address;
	assign kernel_write = read_in_progress ? 1'b0 : kernel_write_req ;
  assign kernel_read = read_in_progress ? (read_state == STATE_READ_REQUEST): 1'b0 ;
	assign kernel_writedata = cciconfig_writedata;
  
  
	assign  ccidata_byteenable = {64{1'b1}};
	assign  ccidata_write =  (read_state == STATE_WRITE_REQUEST);
	assign  ccidata_writedata = {(read_counter+1'b1),read_data};
	assign  ccidata_read = 0;
  assign  ccidata_address = cci_addr;

endmodule
