
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
