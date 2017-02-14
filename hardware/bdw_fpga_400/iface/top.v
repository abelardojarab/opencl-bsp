
module top(

   //////// CLOCK //////////
   input config_clk,  // 100MHz clock 

   //////// LED //////////
   output [7:0] leds
);

//=======================================================
//  PARAMETER declarations
//=======================================================

//=======================================================
//  REG/WIRE declarations
//=======================================================
wire resetn;

//=======================================================
//  Board-specific 
//=======================================================


//=======================================================
//  Reset logic 
//=======================================================
assign resetn = 1'b1;  // No hard reset !!!

//=======================================================
//  System instantiation
//=======================================================

system system_inst 
(
   // Global signals
   .global_reset_reset_n( resetn ),
   .config_clk_clk( config_clk ),

   .kernel_pll_refclk_clk( config_clk )
);

assign leds[7:0] = 8'b0101000;

endmodule
