// We need to convert byte enabled stores into multiple aligned power-of-2 stores
// we'll do this suboptimally at first as we'll focus on streaming accesses
localparam OFFSET_BITS=$clog2(SVM_BYTEEN_WIDTH);
reg [SVM_BYTEEN_WIDTH-1:0] inital_byte_en;
reg [SVM_BYTEEN_WIDTH-1:0] current_byte_en;     
reg [63:0] current_addr;

wire [SVM_BYTEEN_WIDTH-1:0] next_byte_en;     
wire [OFFSET_BITS-1:0] shiftlen;
wire [OFFSET_BITS-1:0] transaction_length;
wire [SVM_BYTEEN_WIDTH-1:0];
wire full_word;
wire [63:0] next_addr;

//for now just try and detect most common and useful cases (4 bytes 1 bytes)
assign transaction_length =  ((current_byte_en[0]) ? ((&current_byte_en[3:0] ? 3'b100 : :  1'b1) : 0 );  
assign shiftlen = transaction_length ? transaction_length : 1;
assign next_byte_en = current_byte_en >> shiftlen;
assign done = (~|next_byte_en) | full_word ;
assign full_word = &current_byte_en;
assign next_addr = current_addr+shiftlen;


//output

assign 

 
always@(posedge clk or posedge reset) begin
   if(reset == 1'b1)
   begin
    current_offset <= 0;
    current_size <= 0;
    inital_byte_en <= 0;
    current_byte_en <= 0;    
   end
   else
   begin
   
   end

end
    