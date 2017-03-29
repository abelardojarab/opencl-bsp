// Wrapper for IBM CAPI PSL
// MM Master for controlling kernel
// MM Slave for SVM
module write_combiner
#(

    
    // SVM Memory Slave
    parameter AVM_WIDTH           = 512,
    parameter AVM_ADDR_WIDTH      = 64,
    parameter AVM_BYTEEN_WIDTH = 64,
    //parameter PIPELINE_COMMAND     = 1,
    //parameter PIPELINE_RESPONSE    = 1,

    
)
(
    input                           clk,
    input                           reset,

    output                          s0_waitrequest,
    output [AVM_WIDTH-1:0]         s0_readdata,
    output                          s0_readdatavalid,
    input  [AVM_WIDTH-1:0]         s0_writedata,
    input  [AVM_ADDR_WIDTH-1:0]     s0_address, 
    input                           s0_write,  
    input                           s0_read,  
    input  [AVM_BYTEEN_WIDTH-1:0]       s0_byteenable,  

    input                          m0_waitrequest,
    input [AVM_WIDTH-1:0]         m0_readdata,
    input                          m0_readdatavalid,
    output  [AVM_WIDTH-1:0]         m0_writedata,
    output  [AVM_ADDR_WIDTH-1:0]     m0_address, 
    output                           m0_write,  
    output                           m0_read,  
    output  [AVM_BYTEEN_WIDTH-1:0]       m0_byteenable
);


    
endmodule