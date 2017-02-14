

 
module altera_avalon_mm_cci_bridge #(
	parameter PEND_REQS = 512,
	parameter PEND_REQS_LOG2 = 9
	)(
	input clk,
	input reset_n,
  
	input InitDone,
	input virtual_access,
  
	input wire [27:0] rx_c0_header,
	input wire [511:0] rx_c0_data,
	input wire rx_c0_rdvalid,
	input wire rx_c0_wrvalid,
  
  input wire rx_c0_ugvalid,
	input wire rx_c0_mmiowrvalid,
  input wire rx_c0_mmiordvalid,
	input wire rx_c1_irvalid,
  
	output wire tx_c1_irvalid,
	output wire [98:0] tx_c0_header,
	output wire tx_c0_rdvalid,
	input wire tx_c0_almostfull,
	input wire [27:0] rx_c1_header,
	input wire rx_c1_wrvalid,
	output reg [98:0] tx_c1_header,
	output reg [511:0] tx_c1_data,
  output reg [63:0] tx_c1_byteen,
	output reg tx_c1_wrvalid,
	input wire tx_c1_almostfull,
  
  
  
  output wire [8:0] tx_c2_header,
  output wire  tx_c2_rdvalid,
  output wire [63:0] tx_c2_data,
  
  
  
  output wire  nohazards_rd  ,     
  output wire nohazards_wr_full,  
  output wire nohazards_wr_all , 
	
	input wire [57:0] avmm_address,
	input wire [63:0] avmm_byteenable,
  input wire [2:0] avmm_burstcount,
	input wire avmm_write,
	input wire [511:0] avmm_writedata,
	input wire avmm_read,
	output wire [511:0] avmm_readdata,
	output wire avmm_readdatavalid,
	output wire avmm_waitrequest,
	output write_pending,
  
	
	output [14:0] kernel_address,
	output kernel_write,
  output kernel_read,
	output [63:0] kernel_writedata,
	output [7:0] kernel_byteenable,
  input  [63:0] kernel_readdata,
  input  kernel_readdatavalid,
	input  kernel_waitrequest,
  
  input kernel_irq,
  
  input [8:0] addr_cfg_address,
	input addr_cfg_write,
	input [63:0]  addr_cfg_writedata,
  input [7:0]  addr_cfg_byteenable,
  
  
  input [8:0] debug_address,
	input debug_read,
	output reg [63:0]  debug_readdata,
  output  reg debug_readdatavalid
  
  
	);


	wire [PEND_REQS_LOG2-2:0] read_tag;
	wire read_tag_ready;
	wire read_tag_valid;
	wire [PEND_REQS_LOG2-2:0] write_tag;
	wire write_tag_ready;
	wire write_tag_valid;
  wire transaction_pending;
	
	assign tx_c1_irvalid = 1'b0;

	//MMIO interface
	// 4 byte aligned address
	// 4 byte size


	 //---------------------------------------------------------
	 // CAFU initiated Requests  ***** DO NOT MODIFY ******
	 //---------------------------------------------------------
	 localparam       WrThru              = 4'h0;
	 localparam       WrLine              = 4'h1;
	 localparam       RdLine              = 4'h1;
	 localparam       WrFence             = 4'h4;
	 localparam       Intr                = 4'h8;    // FPGA to CPU interrupt
	
   localparam INT_MDATA = 16'h1FFF;	

                                                     
  wire [511:0] int_data = {   512{1'b1}   };                                                   
  wire [511:0] clr_data = {   512{1'b0}   };                                                
                                                     
                                                     
  wire [98:0] id_hdr;
  wire [98:0] fence_hdr;
  wire [98:0] int_hdr;
	wire [63:0] cr_dsm_base;
																
	assign 	int_hdr = {
                                                     2'b01,                     // [73:72] VC SEL
                                                     1'b1,                      // [71] SOP
                                                     1'h0,                      //[70] RSVD
                                                     2'h0,                      // [69:68]     Length
                                                     WrThru,                    // [55:52]      Request Type
                                                     6'h00,                     // [51:46]      Rsvd
                                                     cr_dsm_base[47:6]+2,          // [44:14]      Address
                                                     16'h1FFF                   // [13:0]       Meta data to track the SPL requests
                                                };
  
  	assign 	fence_hdr = {
                                                     2'b0,                     // [73:72] VC SEL
                                                     1'b1,                      // [71] SOP
                                                     1'h0,                      //[70] RSVD
                                                     2'h0,                      // [69:68]     Length
                                                     WrFence,                    // [55:52]      Request Type
                                                     6'h00,                     // [51:46]      Rsvd
                                                     cr_dsm_base[47:6]+2,          // [44:14]      Address
                                                     16'h1FFF                  // [13:0]       Meta data to track the SPL requests
                                                };
  
  
  

	
	// need to override c1_tx_data and c1_tx_hdr and c1_tx_wrvalid when write_id validl
  
	wire  [98:0]  tx_c1_header_internal;
	wire [511:0] tx_c1_data_internal;
  wire [63:0] tx_c1_byteen_internal;
	wire tx_c1_wrvalid_internal;
	wire [98:0] tx_c0_header_internal;
  reg     [2:0] irq_state;
  parameter WAITING = 0, FLUSHING = 5, INT_FENCE = 1,INT_REC = 2, INT_SENT = 3, INT_CLEAR=4  ;
  wire irq_posted;
  wire write_fence; 
  wire write_irq;
  assign write_irq = ((irq_state == INT_REC)  )  && !tx_c1_wrvalid_internal && !tx_c1_almostfull ;
  wire clear_irq;
  assign clear_irq = ((irq_state == INT_CLEAR)  )  && !tx_c1_wrvalid_internal && !tx_c1_almostfull ;
  assign write_fence = ((irq_state == INT_FENCE) )  && !tx_c1_wrvalid_internal && !tx_c1_almostfull ;

 
 

  reg [9:0] timer;
 
  always @ (posedge clk) begin
  if ((reset_n == 1'b0)) begin
  irq_state <= WAITING;

  
  end else
  case (irq_state)
     WAITING: begin
        irq_state <= kernel_irq ? FLUSHING : WAITING;
        timer <= 1;
        end
     FLUSHING: begin
        irq_state <= (write_pending | avmm_write  | avmm_read | (timer < 32) )? FLUSHING : INT_FENCE;    
        timer <= timer+1;
        end
     INT_FENCE: begin
         irq_state <= write_fence ? INT_REC : INT_FENCE;        
          end
     INT_REC: begin
         irq_state <= write_irq ? INT_SENT : INT_REC;
         end
     INT_SENT: begin
        irq_state <= kernel_irq ? INT_SENT : INT_CLEAR;
        end
     INT_CLEAR: begin
         irq_state <= clear_irq ? WAITING : INT_CLEAR;
         end
  endcase
  end
 
 
 
	
	
	always @ (posedge clk) begin
	 tx_c1_header <=  ( write_irq || clear_irq) ? int_hdr : write_fence ? fence_hdr :  tx_c1_header_internal;
	 tx_c1_data <=     write_irq ? int_data : clear_irq ? clr_data:  tx_c1_data_internal;
	 tx_c1_wrvalid <= (write_irq || write_fence || clear_irq) ? 1'b1 : tx_c1_wrvalid_internal;	
   tx_c1_byteen <= (write_irq || write_fence || clear_irq) ? {64{1'b1}} : tx_c1_byteen_internal;	   
  end

	
	wire mmio_write;
  wire mmio_read;
	wire [1:0] mmio_length;
	wire [15:0] mmio_address;
	wire [63:0] mmio_writedata;
	wire [8:0] mmio_tid;
	
	wire mmio_waitrequest;

	wire [93:0] fifo_in = {  rx_c0_mmiowrvalid,rx_c0_mmiordvalid, rx_c0_data[63:0],rx_c0_header[27:0] };
	wire [93:0] fifo_out;
	
	reg outstanding_read;
	reg [8:0] oustanding_tid;
	reg outstanding_unaligned;
  
`define WORKAROUND_MMIO_BIT_6 
`ifdef WORKAROUND_MMIO_BIT_6 
	assign kernel_address = {mmio_address[15:5],    mmio_address[3:1]};
`else   
	assign kernel_address = mmio_address[15:1];
`endif

	assign kernel_write = mmio_write && !outstanding_read;
  assign kernel_read = mmio_read && !outstanding_read;
	assign kernel_writedata = ( mmio_length==2'b1 ) ||  !mmio_address[0] ? mmio_writedata :  mmio_writedata[31:0] <<32  ;
	assign kernel_byteenable =  ( mmio_length==2'b1 ) ? 8'b11111111 : mmio_address[0] ? 8'b11110000 : 8'b00001111;
	assign mmio_waitrequest = kernel_waitrequest || outstanding_read;
	
	always @ (posedge clk or negedge reset_n) begin
  if ((reset_n == 1'b0)) begin
		outstanding_read <= 0;
		oustanding_tid <= 'x;
		outstanding_unaligned <= 'x;
  end else
		if(kernel_read && !kernel_waitrequest) begin
			outstanding_read <= 1'b1;
			oustanding_tid <= mmio_tid;
			outstanding_unaligned <= ( mmio_length==2'b0 ) && mmio_address[0];
		end else if ( outstanding_read) begin
			outstanding_read <= !kernel_readdatavalid;
			oustanding_tid <= oustanding_tid;
			outstanding_unaligned <= outstanding_unaligned;
		end else begin
			outstanding_read <= 0;
			oustanding_tid <= oustanding_tid;
			outstanding_unaligned <= outstanding_unaligned;			
		end
  end
	
  assign  tx_c2_header = oustanding_tid;
  assign tx_c2_rdvalid = kernel_readdatavalid && outstanding_read;
  assign tx_c2_data = outstanding_unaligned ?  kernel_readdata[63:32] : kernel_readdata;

 
	// MMIO FIFO

	wire mmio_waitrequest_fifo;

	reg [63:0] mmio_writedata_fifo;

	wire mmio_fifo_empty;
		
  assign  mmio_write = ~mmio_fifo_empty && fifo_out[93];
	assign  mmio_read = ~mmio_fifo_empty && fifo_out[92];
	
	assign mmio_length = fifo_out[11:10];
	assign mmio_address  = fifo_out[27:12];
	assign mmio_writedata = fifo_out[63+28:28];

	assign mmio_tid = fifo_out[8:0];
	
  
	
	
	wire valid_mmio = (rx_c0_mmiowrvalid || rx_c0_mmiordvalid) && ( ( rx_c0_header[27:12] < 16'h400) || ( rx_c0_header[27:12] > 16'h800) );
  
  scfifo	scfifo_component (
			.clock (clk),
			.data  (fifo_in ),
			.rdreq (~mmio_waitrequest & ~mmio_fifo_empty),
			.wrreq (valid_mmio),
			.empty (mmio_fifo_empty),
			.full  (mmio_waitrequest_fifo),
			.q     (fifo_out),
			.usedw (),
			.aclr  (~reset_n),
			.almost_empty (),
			.almost_full (),
			.sclr (~reset_n));
defparam
	scfifo_component.add_ram_output_register = "ON",
	scfifo_component.intended_device_family = "ARRIA 10",
	scfifo_component.lpm_numwords = 8,
	scfifo_component.lpm_showahead = "ON",
	scfifo_component.lpm_type = "scfifo",
	scfifo_component.lpm_width  = 128,
	scfifo_component.lpm_widthu = 3,
	scfifo_component.overflow_checking = "ON",
	scfifo_component.underflow_checking = "OFF",
	scfifo_component.use_eab = "OFF";
  


  
  wire [7:0] tx_flags;
  
  wire rule_match;
  wire [63:0] cci_config;
  wire use_bridge_mapping_r = cci_config[0]; 
  wire use_bridge_mapping_w = cci_config[1];	
  wire use_vl_r			    = cci_config[2]; 
  wire use_vl_w	            = cci_config[3]; 
  wire use_vh_r             = cci_config[4];	
  wire use_vh_w	            = cci_config[5]; 
  wire use_rdline_i         = cci_config[6]; 
  wire use_wrline_i         = cci_config[7]; 
  assign nohazards_rd         		= cci_config[8]; 
  assign nohazards_wr_full    		= cci_config[9]; 
  assign nohazards_wr_all     		= cci_config[10]; 




  
  assign  rule_match = 0;
  	addr_range_cmp #(
    .NUM_RULES(16),
    .NUM_RULES_LOG2(4),
    .FLAG_WIDTH(8)
	) addr_range_cmpinst (
		.clk(clk),
		.reset_n(reset_n),
		.rx_valid(avmm_write || avmm_read),
		.rx_addr({avmm_address, 6'b0}),
		.tx_flags(tx_flags),
    .tx_valid(/*rule_match*/),
		.cfg_address(addr_cfg_address),
		.cfg_write(addr_cfg_write),
		.cfg_writedata(addr_cfg_writedata),
    .cfg_byteenable(addr_cfg_byteenable),
		.dsm_base(cr_dsm_base),
    .cci_config(cci_config)

	);
  
  

  
  cci_requester #(
		.PEND_REQS(PEND_REQS),
		.PEND_REQS_LOG2(PEND_REQS_LOG2)
	) cci_requester_inst (
		.clk(clk),
		.reset_n(reset_n),
		.virtual_access(1'b1),
		.request_type(avmm_write ? rule_match ? tx_flags[7:4] : WrLine : rule_match ? tx_flags[3:0] : RdLine ),
		.rx_c0_header(rx_c0_header),
		.rx_c0_data(rx_c0_data),
		.rx_c0_rdvalid(rx_c0_rdvalid),
		.rx_c0_wrvalid(rx_c0_wrvalid && (rx_c0_header[15:0] != INT_MDATA )),
		.tx_c0_header(tx_c0_header),
		.tx_c0_rdvalid(tx_c0_rdvalid),
		.tx_c0_almostfull(tx_c0_almostfull),
		.rx_c1_header(rx_c1_header),
		.rx_c1_wrvalid(rx_c1_wrvalid && (rx_c1_header[15:0] != INT_MDATA )),
		.tx_c1_header(tx_c1_header_internal),
		.tx_c1_data(tx_c1_data_internal),
		.tx_c1_wrvalid(tx_c1_wrvalid_internal),
		.tx_c1_almostfull(tx_c1_almostfull),
		.tx_c1_byteen(tx_c1_byteen_internal),
		.avmm_address(avmm_address),
		.avmm_byteenable(avmm_byteenable),
		.avmm_burstcount(avmm_burstcount),
		.avmm_write(avmm_write),
		.avmm_writedata(avmm_writedata),
		.avmm_read(avmm_read),
		.avmm_waitrequest(avmm_waitrequest),
		.read_tag(read_tag),
		.read_tag_ready(read_tag_ready),
		.read_tag_valid(read_tag_valid),
		.write_tag(write_tag),
		.write_tag_ready(write_tag_ready),
		.write_tag_valid(write_tag_valid),
		.transaction_pending(transaction_pending),
		.use_bridge_mapping_r (use_bridge_mapping_r),
		.use_bridge_mapping_w (use_bridge_mapping_w),
		.use_vl_r			 (use_vl_r			 ),
		.use_vl_w	         (use_vl_w	         ),
		.use_vh_r             (use_vh_r            ),
		.use_vh_w	         (use_vh_w	         ),
		.use_rdline_i         (use_rdline_i        ),
		.use_wrline_i         (use_wrline_i        )
		
	);


	read_granter #(
		.PEND_REQS(PEND_REQS/2),
		.PEND_REQS_LOG2(PEND_REQS_LOG2-1)
	) read_granter_inst (
		.clk(clk),
		.reset_n(reset_n),
		.avmm_readdata(avmm_readdata),
		.avmm_readdatavalid(avmm_readdatavalid),
		.rx_c0_rdvalid(rx_c0_rdvalid),
		.rx_c0_header(rx_c0_header),
		.rx_c0_data(rx_c0_data),
		.read_tag(read_tag),
		.read_tag_ready(read_tag_ready),
		.read_tag_valid(read_tag_valid)
	);
	
	write_granter #(
		.PEND_REQS(PEND_REQS/2),
		.PEND_REQS_LOG2(PEND_REQS_LOG2-1)
	) write_granter_inst (
		.clk(clk),
		.reset_n(reset_n),
		.rx_c0_header(rx_c0_header),
		.rx_c0_wrvalid(rx_c0_wrvalid && (rx_c0_header[15:0] != INT_MDATA )),
		.rx_c1_header(rx_c1_header),
		.rx_c1_wrvalid(rx_c1_wrvalid && (rx_c1_header[15:0] != INT_MDATA )),
		.write_tag(write_tag),
		.write_tag_ready(write_tag_ready),
		.write_tag_valid(write_tag_valid),
		.write_pending(write_pending)
	);
	

  reg [63:0] debug_registers [0:64-1];
  
  
  
  reg [31:0] num_writes;
  reg [31:0] num_reads;
  reg [31:0] num_partial_writes;
  
  reg partial_write;
  /*
  	input wire [57:0] avmm_address,
	input wire [63:0] avmm_byteenable,
	input wire avmm_write,
	input wire [511:0] avmm_writedata,
	input wire avmm_read,
	output wire [511:0] avmm_readdata,
	output wire avmm_readdatavalid,
	output wire avmm_waitrequest,
	output write_pending,
  
  
  */
  
  always @ (posedge clk or negedge reset_n) begin
  if ((reset_n == 1'b0)) begin
		num_writes <= 0;
		num_reads <= 0;
		num_partial_writes <= 0;
		partial_write <= 0;
  end else begin
		num_writes <= avmm_write && ! avmm_waitrequest ? num_writes+1:num_writes;
		num_reads <= avmm_read && ! avmm_waitrequest ? num_reads+1:num_reads;
		num_partial_writes <= partial_write ? num_partial_writes+1:num_partial_writes;
		partial_write <= avmm_write && ! avmm_waitrequest && !(&avmm_byteenable) ;
  end
  end
  
  
  
  always @(posedge clk) begin 
    debug_registers[0] <= transaction_pending;
    debug_registers[1] <= write_pending;
    debug_registers[2] <= avmm_waitrequest;
    debug_registers[3] <= kernel_irq;
    // c1
    debug_registers[4] <= tx_c0_almostfull;
    debug_registers[5] <= tx_c1_almostfull;
    debug_registers[6] <= 32'hBEADBEAD;
    debug_registers[7] <= num_writes;
    debug_registers[8] <= num_reads;
    debug_registers[9] <= num_partial_writes;
  end
  
  

  
		always @(posedge clk) begin 
       debug_readdata <= debug_registers[debug_address];
       debug_readdatavalid <= debug_read;
		end


endmodule
