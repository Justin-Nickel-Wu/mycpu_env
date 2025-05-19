module decoder_2_4(
    input  wire [ 1:0] in,
    output wire [ 3:0] out
);

genvar i;
generate for (i=0; i<4; i=i+1) begin : gen_for_dec_2_4
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_4_16(
    input  wire [ 3:0] in,
    output wire [15:0] out
);

genvar i;
generate for (i=0; i<16; i=i+1) begin : gen_for_dec_4_16
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_5_32(
    input  wire [ 4:0] in,
    output wire [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  wire [ 5:0] in,
    output wire [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule

module one_valid_n #(
	parameter n = 16
)(
	input  [n-1:0] in,
	output [n-1:0] out,
	output         nozero
);

wire [n-1:0] one_in;

assign one_in[0] = in[0];

genvar i;
generate 
	for (i=1; i<n; i=i+1)
	begin: sel_one
		assign one_in[i] = in[i] && ~|in[i-1:0];
	end
endgenerate

assign out = one_in;
assign nozero = |out;

endmodule