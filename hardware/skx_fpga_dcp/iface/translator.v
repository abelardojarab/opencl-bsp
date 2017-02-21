// Wrapper for IBM CAPI PSL
// MM Master for controlling kernel
// MM Slave for SVM
module translator
#(

    
    // SVM Memory Slave
    parameter SVM_WIDTH           = 512,
    parameter SVM_ADDR_WIDTH      = 64,
    parameter SVM_BURSTCOUNT_WIDTH   = 2,    
    parameter SVM_BYTEEN_WIDTH = 64,
    //parameter PIPELINE_COMMAND     = 1,
    //parameter PIPELINE_RESPONSE    = 1,

    
)
(
    input                           clk,
    input                           reset,

    output                          s0_waitrequest,
    output [SVM_WIDTH-1:0]         s0_readdata,
    output                          s0_readdatavalid,
    input  [SVM_BURSTCOUNT_WIDTH-1:0]   s0_burstcount,
    input  [SVM_WIDTH-1:0]         s0_writedata,
    input  [SVM_ADDR_WIDTH-1:0]     s0_address, 
    input                           s0_write,  
    input                           s0_read,  
    input  [SVM_BYTEEN_WIDTH-1:0]       s0_byteenable,  

    // read request
    input psl_r_ready,
    output psl_r_request,
    output [SVM_ADDR_WIDTH-1:0] psl_r_ea,
    output [12:0] psl_r_size,
    
    // read response
    input psl_r_data_ready,
    input [SVM_WIDTH-1:0] psl_r_data,
    output psl_r_ack,
    
    
    // write request
    input psl_w_ready,
    output psl_w_request,
    output [SVM_ADDR_WIDTH-1:0] psl_w_ea,
    output [12:0] psl_w_size,
    output [SVM_WIDTH-1:0] psl_w_data,
    input [SVM_WIDTH-1:0] psl_w_data_ready,
    // write response
    output psl_w_data
    output psl_w_ack,    
    
    
        
/*
    -- Port 1 (Read)
    ready1: out std_ulogic;
    req1: in std_ulogic;
    ea1: in std_ulogic_vector(0 to 63);
    size1: in std_ulogic_vector(0 to 12);
    data_ready1: out std_ulogic;
    data1: out std_ulogic_vector(0 to 511);
    data_ack1: in std_ulogic;
    -- Port 2 (Write)
    ready2: out std_ulogic;
    req2: in std_ulogic;
    ea2: in std_ulogic_vector(0 to 63);
    size2: in std_ulogic_vector(0 to 12);
    data_ready2: out std_ulogic;
    data2: in std_ulogic_vector(0 to 511);
    data_ack2: in std_ulogic;
*/    
);
    
    
    
    

    
    
/*
If 








*/    
    
    scfifo #(
      .add_ram_output_register ( "ON"),
      .intended_device_family ( DEVICE),
      .lpm_numwords (OFFSET_FIFO_DEPTH),
      .lpm_showahead ( "OFF"),
      .lpm_type ( "scfifo"),
      .lpm_width (OFFSET_FIFO_WIDTH),
      .lpm_widthu (OFFSET_FIFO_AW),
      .overflow_checking ( "OFF"),
      .underflow_checking ( "ON"),
      .use_eab ( "ON"),
      .almost_full_value(OFFSET_FIFO_DEPTH - 10)
    ) offset_fifo (
      .clock (clk),
      .data (offset_fifo_din),
      .wrreq (i_word_offset_valid),
      .rdreq (rd_offset),
      .usedw (offset_flv),
      .empty (offset_fifo_empty),
      .full (offset_overflow),
      .q (offset_fifo_dout),
      .almost_empty (),
      .almost_full (offset_af),
      .aclr (reset)
    );    
    
    
endmodule