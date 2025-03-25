module StableCounter(
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] cntvl,
    output wire [31:0] cntvh
);

reg  [63:0] cntv;

assign cntvl = cntv[31: 0];
assign cntvh = cntv[63:32];

always @(posedge clk) begin
    if (reset)
        cntv <= 64'h0;
    else
        cntv <= cntv + 1;
end
endmodule