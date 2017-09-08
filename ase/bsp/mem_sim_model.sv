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

module mem_sim_model (
  input   wire                          clk,
  input wire reset,
  output   logic                          avmm_waitrequest,
  output   logic [511:0]                  avmm_readdata,
  output   logic                          avmm_readdatavalid,
  input  wire [6:0]                    avmm_burstcount,
  input  wire [511:0]                  avmm_writedata,
  input  wire [25:0]                   avmm_address,
  input  wire                          avmm_write,
  input  wire                          avmm_read,
  input  wire [63:0]                   avmm_byteenable
  );
	
	initial avmm_readdata = 512'b0;
	initial avmm_readdatavalid = 0;
	reg  [511:0] mem_array[ reg [25:0] ]; // Fake emif sim model, we model 2 banks of memory using systemverilog associative arrays
	
	wire [511:0] avmm_byteenable_mask;
	reg [511:0] tmp_read = 0;
	reg [6:0] avmm_burst_state = 0;
	reg [25:0]  avmm_burst_address = 0;
	reg [511:0] avmm_burst_byteenable_mask = 0;
	genvar i;
	generate
	for (i = 0; i < 64 ; i = i + 1) 
	begin: gen_loop1 
		assign avmm_byteenable_mask[(i+1)*8-1:i*8] = {8{avmm_byteenable[i]}};
	end
	endgenerate
	
	reg avmm_is_reset;
	initial avmm_is_reset = 0;
	initial avmm_burst_address = 0;
	reg is_read_burst = 0;
	reg is_write_burst = 0;
	assign avmm_waitrequest = (avmm_burst_state != 6'b000000) & is_read_burst;
	
	always @(posedge clk) begin
		if (reset || ~avmm_is_reset) begin // global reset
			avmm_readdata      <= 512'b0;
			avmm_readdatavalid <= 1'b0;
			avmm_burst_state <= 6'b0;
			avmm_burst_address <= 25'b0;
			avmm_burst_byteenable_mask <= 512'b0;
			is_read_burst <= 1'b0;
			is_write_burst <= 1'b0;
			avmm_is_reset <= 1'b1;
		end
		else begin
			avmm_readdatavalid <= 1'b0;
			if(!(is_read_burst | is_write_burst)) begin
				if (avmm_read) begin
					avmm_burst_state <= avmm_burstcount;
					avmm_burst_address <= avmm_address;
					avmm_burst_byteenable_mask <= avmm_byteenable_mask;
					is_read_burst <= avmm_read;
				end
				else if (avmm_write) begin
					avmm_burst_state <= avmm_burstcount-1;
					avmm_burst_address <= avmm_address+1;
					avmm_burst_byteenable_mask <= avmm_byteenable_mask;
					is_write_burst <= (avmm_burstcount != 6'b000001);
					//need to write first word!
					if (mem_array.exists(avmm_address)) tmp_read = mem_array[avmm_address];
					else tmp_read = 512'b0;
					mem_array[avmm_address] <= (tmp_read & ~avmm_byteenable_mask) | (avmm_writedata & avmm_byteenable_mask);
				end
			end
			else if(is_read_burst) begin
				avmm_burst_state <= avmm_burst_state - 1;
				avmm_burst_address <= avmm_burst_address + 1;
				if(is_read_burst) begin
					if (mem_array.exists(avmm_burst_address)) avmm_readdata <= mem_array[avmm_burst_address];
					else avmm_readdata <= 512'b0;
					avmm_readdatavalid <= 1'b1;
					is_read_burst <= (avmm_burst_state != 6'b000001);
				end
			end 
			else if(is_write_burst) begin
				if (avmm_write) begin
					avmm_burst_state <= avmm_burst_state - 1;
					avmm_burst_address <= avmm_burst_address + 1;
					if (mem_array.exists(avmm_burst_address)) tmp_read = mem_array[avmm_burst_address];
					else tmp_read = 512'b0;
					mem_array[avmm_burst_address] <= (tmp_read & ~avmm_burst_byteenable_mask) | (avmm_writedata & avmm_burst_byteenable_mask);
					is_write_burst <= (avmm_burst_state != 6'b000001);
				end
			end
		end
	end
	

endmodule