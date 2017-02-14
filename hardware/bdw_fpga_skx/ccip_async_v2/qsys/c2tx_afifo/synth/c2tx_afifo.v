// c2tx_afifo.v

// Generated using ACDS version 15.1 193

`timescale 1 ps / 1 ps
module c2tx_afifo (
		input  wire [73:0] data,    //  fifo_input.datain
		input  wire        wrreq,   //            .wrreq
		input  wire        rdreq,   //            .rdreq
		input  wire        wrclk,   //            .wrclk
		input  wire        rdclk,   //            .rdclk
		input  wire        aclr,    //            .aclr
		output wire [73:0] q,       // fifo_output.dataout
		output wire [8:0]  rdusedw, //            .rdusedw
		output wire [8:0]  wrusedw, //            .wrusedw
		output wire        rdfull,  //            .rdfull
		output wire        rdempty, //            .rdempty
		output wire        wrfull,  //            .wrfull
		output wire        wrempty  //            .wrempty
	);

	c2tx_afifo_fifo_151_myrce6a fifo_0 (
		.data    (data),    //  fifo_input.datain
		.wrreq   (wrreq),   //            .wrreq
		.rdreq   (rdreq),   //            .rdreq
		.wrclk   (wrclk),   //            .wrclk
		.rdclk   (rdclk),   //            .rdclk
		.aclr    (aclr),    //            .aclr
		.q       (q),       // fifo_output.dataout
		.rdusedw (rdusedw), //            .rdusedw
		.wrusedw (wrusedw), //            .wrusedw
		.rdfull  (rdfull),  //            .rdfull
		.rdempty (rdempty), //            .rdempty
		.wrfull  (wrfull),  //            .wrfull
		.wrempty (wrempty)  //            .wrempty
	);

endmodule
