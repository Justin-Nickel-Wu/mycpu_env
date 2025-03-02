module alu(
  input  wire        clk,
  input  wire        reset,

  input  wire [16:0] alu_op,
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result,

  output wire 		 alu_wait
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate
wire op_mul_w;
wire op_mulh_w;
wire op_mulh_wu;
wire op_div_w;
wire op_mod_w;

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_mul_w   = alu_op[12];
assign op_mulh_w  = alu_op[13];
assign op_mulh_wu = alu_op[14];
assign op_div_w   = alu_op[15];
assign op_mod_w   = alu_op[16];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;


// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign alu_wait = signed_div_wait;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5
assign sr_result   = sr64_result[31:0];

//MUL result
wire [32:0] muler_a;
wire [32:0] muler_b;
wire [65:0] mul_result;

assign muler_a = op_mulh_w ? {alu_src1[31], alu_src1} :
         /*mul_w | mulh_wu*/ {{1'b0}, alu_src1};
assign muler_b = op_mulh_wu ? {alu_src2[31], alu_src2} :
         /*mul_w | mulh_w*/ {{1'b0}, alu_src2};
assign mur_result = $signed(muler_a) * $signed(muler_b);

//DIV result
wire        signed_dividend_tready;
reg         signed_dividend_tvalid;
wire        signed_divisor_tready;
reg         signed_divisor_tvalid;
wire [63:0]	signed_div_tdata;
wire 		signed_div_tvalid;
wire 		is_signed_div;

wire		signed_div_wait;
reg  [ 1:0] signed_div_state;

localparam IDLE = 0,
           SEND_DATA = 1,
           WAIT_FOR_RESULT = 2;

assign is_signed_div = op_div_w || op_mod_w;

always @(posedge clk) begin
	if (reset) begin
		signed_div_state <= IDLE;
		signed_dividend_tvalid <= 1'b0;
		signed_divisor_tvalid <= 1'b0;
	end else begin
		case (signed_div_state) 
			IDLE: begin
				if (is_signed_div) begin
					signed_dividend_tvalid <= 1'b1;
					signed_divisor_tvalid <= 1'b1;
					signed_div_state <= SEND_DATA;
				end
			end
			SEND_DATA: begin
				if (signed_dividend_tready && signed_divisor_tready) begin
					signed_dividend_tvalid <= 1'b0;
					signed_divisor_tvalid <= 1'b0;
					signed_div_state <= WAIT_FOR_RESULT;
				end
			end
			WAIT_FOR_RESULT: begin
				if (signed_div_tvalid) begin
					signed_div_state <= IDLE;
				end
			end
		endcase
	end
end

assign signed_div_wait = is_signed_div && (~signed_div_tvalid);

signed_div u_signed_div(
	.aclk                     (clk),

	.s_axis_dividend_tdata    (alu_src1),
	.s_axis_dividend_tready   (signed_dividend_tready),
	.s_axis_dividend_tvalid   (signed_dividend_tvalid),

	.s_axis_divisor_tdata     (alu_src2),
	.s_axis_divisor_tready    (signed_divisor_tready),
	.s_axis_divisor_tvalid    (signed_divisor_tvalid),

	.m_axis_dout_tdata        (signed_div_tdata),
	.m_axis_dout_tvalid       (signed_div_tvalid)
);

// final result mux
assign alu_result = op_add | op_sub ? add_sub_result  :
                    op_slt          ? slt_result      :
                    op_sltu         ? sltu_result     :
                    op_and          ? and_result      :
                    op_nor          ? nor_result      :
                    op_or           ? or_result       :
                    op_xor          ? xor_result      :
                    op_lui          ? lui_result      :
                    op_sll          ? sll_result      :
                    op_srl | op_sra ? sr_result       :
                    op_mul_w               ? mul_result[31: 0]:
                    op_mulh_w | op_mulh_wu ? mul_result[63:32]:
					op_div_w		? signed_div_tdata[63:32] :
					op_mod_w		? signed_div_tdata[31: 0] : 32'b0;
endmodule
