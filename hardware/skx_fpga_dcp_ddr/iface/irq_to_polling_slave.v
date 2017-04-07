module irq_to_polling_slave (
    clk,
    reset,

    read,
    irq_readdata,

    interrupt
);

parameter DATA_WIDTH = 32;

input clk;
input reset;

input read;
output [DATA_WIDTH-1:0] irq_readdata;
input interrupt;

(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *irq_to_polling_slave:*|irq_readdata,*]\""} *) reg [DATA_WIDTH-1:0] irq_readdata;

always@(posedge clk)
begin
  irq_readdata <= interrupt;
end

endmodule
