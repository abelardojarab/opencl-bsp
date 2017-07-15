// ***************************************************************************
// Copyright (c) 2017, Intel Corporation
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// * Neither the name of Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// ***************************************************************************

module addr_range_cmp #(
	parameter NUM_RULES = 32,
	parameter NUM_RULES_LOG2 = 5,
  parameter FLAG_WIDTH = 32,
  parameter CFG_WIDTH = 10
	)(
	input clk,
	input reset_n,
	
	input wire [CFG_WIDTH-1:0] cfg_address,
	input wire cfg_write,
	input wire [63:0] cfg_writedata,
  input wire [7:0] cfg_byteenable,
  
  input wire rx_valid,
  input wire [63:0] rx_addr,
  output reg tx_valid,
  output reg [FLAG_WIDTH-1:0] tx_flags,
	output reg [63:0] dsm_base,
  output reg  [63:0] cci_config

	);

	wire [63:0] rule_base [0:NUM_RULES-1];
  wire [63:0] rule_size [0:NUM_RULES-1];
	
	reg [63:0] rule_max [0:NUM_RULES-1];
  wire [FLAG_WIDTH:0] rule_flags [0:NUM_RULES-1];
  reg [NUM_RULES-1:0] rule_match ;
  
  
  reg [63:0] ram[0:NUM_RULES*4-1];
	
  always @(posedge clk) begin 
  if (cfg_write) begin
    if(cfg_byteenable[0]) ram[cfg_address][7:0] <= cfg_writedata[7:0]; 
    if(cfg_byteenable[1]) ram[cfg_address][15:8] <= cfg_writedata[15:8]; 
    if(cfg_byteenable[2]) ram[cfg_address][23:16] <= cfg_writedata[23:16]; 
    if(cfg_byteenable[3]) ram[cfg_address][31:24] <= cfg_writedata[31:24];
    if(cfg_byteenable[4]) ram[cfg_address][39:32] <= cfg_writedata[39:32]; 
    if(cfg_byteenable[5]) ram[cfg_address][47:40] <= cfg_writedata[47:40]; 
    if(cfg_byteenable[6]) ram[cfg_address][55:48] <= cfg_writedata[55:48]; 
    if(cfg_byteenable[7]) ram[cfg_address][63:56] <= cfg_writedata[63:56];
  end

end

  
genvar k,j;
generate

	for (k=0; k<NUM_RULES; k=k+1)
	begin : i0
      assign rule_base[k] = ram[k];
      assign rule_size[k] = ram[NUM_RULES+k];
      assign rule_flags[k] = ram[NUM_RULES*2+k];
			
			
			always @(posedge clk) begin 
				rule_max[k] <= rule_base[k] + rule_size[k];
				rule_match[k] =  rx_valid && (rx_addr >= rule_base[k] ) && ( rx_addr < rule_max[k] ) ; //add one more cycle here
		 end 
			

	end	

	for (j=0; j<FLAG_WIDTH; j=j+1)
	begin : jl
		reg [NUM_RULES-1:0] tmp_mask;
		for (k=0; k<NUM_RULES; k=k+1)
		begin : il
		always @(posedge clk) begin 
				tmp_mask[k] <=  rule_flags[k][j] && rule_match[k] ; //add one more cycle here
		end
		end
		
		always @(posedge clk) begin 
				tx_flags[j] <= |(tmp_mask);
		end
	end
  
endgenerate 

 
		always @(posedge clk) begin 
				tx_valid <= |(rule_match);
				dsm_base <= ram[NUM_RULES*3];
        cci_config <= ram[NUM_RULES*3+1];
 
		end
//todo account pr 1 cycle delay elsewhere

endmodule
