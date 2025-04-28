module tlb
#(
    parameter TLBNUM = 16
) (
input wire clk,

//search port 0, for fetch
input  wire [              18:0] s0_vppn,
input  wire                      s0_va_bit12,
input  wire [               9:0] s0_asid,
output wire                      s0_found,
output wire [$clog2(TLBNUM)-1:0] s0_index,
output wire [              19:0] s0_ppn,
output wire [               5:0] s0_ps,
output wire [               1:0] s0_plv,
output wire [               1:0] s0_mat,
output wire                      s0_d,
output wire                      s0_v,

//search port 1, for load/store and INVTLB
input  wire [              18:0] s1_vppn,
input  wire                      s1_va_bit12,
input  wire [               9:0] s1_asid,
output wire                      s1_found,
output wire [$clog2(TLBNUM)-1:0] s1_index,
output wire [              19:0] s1_ppn,
output wire [               5:0] s1_ps,
output wire [               1:0] s1_plv,
output wire [               1:0] s1_mat,
output wire                      s1_d,
output wire                      s1_v,

//invtlb opcode
input  wire                      invtlb_valid,
input  wire [               4:0] invtlb_op,

//write port
input  wire                      we,//高电平有效
input  wire [$clog2(TLBNUM)-1:0] w_index,
input  wire                      w_e,
input  wire [              18:0] w_vppn,
input  wire [               5:0] w_ps,
input  wire [               9:0] w_asid,
input  wire                      w_g,
input  wire [              19:0] w_ppn0,
input  wire [               1:0] w_plv0,   
input  wire [               1:0] w_mat0,
input  wire                      w_d0,
input  wire                      w_v0,
input  wire [              19:0] w_ppn1,
input  wire [               1:0] w_plv1,
input  wire [               1:0] w_mat1,
input  wire                      w_d1,
input  wire                      w_v1,

//read port
input  wire [$clog2(TLBNUM)-1:0] r_index,
output wire                      r_e,
output wire [              18:0] r_vppn,
output wire [               5:0] r_ps,
output wire [               9:0] r_asid,
output wire                      r_g,
output wire [              19:0] r_ppn0,
output wire [               1:0] r_plv0,
output wire [               1:0] r_mat0,
output wire                      r_d0,
output wire                      r_v0,
output wire [              19:0] r_ppn1,
output wire [               1:0] r_plv1,
output wire [               1:0] r_mat1,
output wire                      r_d1,
output wire                      r_v1
);

reg  [TLBNUM-1:0] tlb_e;
reg  [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB  0:4KB
reg  [      18:0] tlb_vppn [TLBNUM-1:0];
reg  [       9:0] tlb_asid [TLBNUM-1:0];
reg               tlb_g    [TLBNUM-1:0];
reg  [      19:0] tlb_ppn0 [TLBNUM-1:0];
reg  [       1:0] tlb_plv0 [TLBNUM-1:0];
reg  [       1:0] tlb_mat0 [TLBNUM-1:0];
reg               tlb_d0   [TLBNUM-1:0];
reg               tlb_v0   [TLBNUM-1:0];
reg  [      19:0] tlb_ppn1 [TLBNUM-1:0];
reg  [       1:0] tlb_plv1 [TLBNUM-1:0];
reg  [       1:0] tlb_mat1 [TLBNUM-1:0];
reg               tlb_d1   [TLBNUM-1:0];
reg               tlb_v1   [TLBNUM-1:0];

wire s0_lowest_bit;
wire s1_lowest_bit;
wire [TLBNUM-1:0] match0;
wire [TLBNUM-1:0] match1;
wire [TLBNUM-1:0] inv_match;

//TLBRD部分
assign r_e    = tlb_e     [r_index];
assign r_vppn = tlb_vppn  [r_index];
assign r_ps   = tlb_ps4MB [r_index] ? 6'd21 : 6'd12; //4MB:21 4KB:12
assign r_asid = tlb_asid  [r_index];
assign r_g    = tlb_g     [r_index];
assign r_ppn0 = tlb_ppn0  [r_index];
assign r_plv0 = tlb_plv0  [r_index];
assign r_mat0 = tlb_mat0  [r_index];
assign r_d0   = tlb_d0    [r_index];
assign r_v0   = tlb_v0    [r_index];
assign r_ppn1 = tlb_ppn1  [r_index];
assign r_plv1 = tlb_plv1  [r_index];
assign r_mat1 = tlb_mat1  [r_index];
assign r_d1   = tlb_d1    [r_index];
assign r_v1   = tlb_v1    [r_index];

//TLBWR与TLBFILL
always @(posedge clk) begin
    if (we) begin
        tlb_e     [w_index] <= w_e; //注意此处tlb_e的赋值与写tlb事件冲突,但实际不会同时发生tlbinv与tlbwr事件
        tlb_ps4MB [w_index] <= w_ps[0];
        tlb_vppn  [w_index] <= w_vppn;
        tlb_asid  [w_index] <= w_asid;
        tlb_g     [w_index] <= w_g;
        tlb_ppn0  [w_index] <= w_ppn0;
        tlb_plv0  [w_index] <= w_plv0;
        tlb_mat0  [w_index] <= w_mat0;
        tlb_d0    [w_index] <= w_d0;
        tlb_v0    [w_index] <= w_v0;
        tlb_ppn1  [w_index] <= w_ppn1;
        tlb_plv1  [w_index] <= w_plv1;
        tlb_mat1  [w_index] <= w_mat1;
        tlb_d1    [w_index] <= w_d1;
        tlb_v1    [w_index] <= w_v1;
    end
end

//INVTLB

//TLB命中判断
//s0部分
assign s0_found = |match0;
assign s0_index = match0[ 0] ?  0 :
                  match0[ 1] ?  1 :
                  match0[ 2] ?  2 :
                  match0[ 3] ?  3 :
                  match0[ 4] ?  4 :
                  match0[ 5] ?  5 :
                  match0[ 6] ?  6 :
                  match0[ 7] ?  7 :
                  match0[ 8] ?  8 :
                  match0[ 9] ?  9 :
                  match0[10] ? 10 :
                  match0[11] ? 11 :
                  match0[12] ? 12 :
                  match0[13] ? 13 :
                  match0[14] ? 14 : 15; //若未找到使用15
assign s0_lowest_bit = tlb_ps4MB[s0_index] ? s0_vppn[8] : s0_va_bit12; //页号实际最低位与页大小相关
assign s0_ppn        = s0_lowest_bit ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s0_ps         = tlb_ps4MB[s0_index] ? 6'd21 : 6'd12; //4MB:21 4KB:12
assign s0_plv        = s0_lowest_bit ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s0_mat        = s0_lowest_bit ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s0_d          = s0_lowest_bit ? tlb_d1  [s0_index] : tlb_d0  [s0_index];
assign s0_v          = s0_lowest_bit ? tlb_v1  [s0_index] : tlb_v0  [s0_index];

//s1部分
assign s1_found = |match1;
assign s1_index = match1[ 0] ?  0 :
                  match1[ 1] ?  1 :
                  match1[ 2] ?  2 :
                  match1[ 3] ?  3 :
                  match1[ 4] ?  4 :
                  match1[ 5] ?  5 :
                  match1[ 6] ?  6 :
                  match1[ 7] ?  7 :
                  match1[ 8] ?  8 :
                  match1[ 9] ?  9 :
                  match1[10] ? 10 :
                  match1[11] ? 11 :
                  match1[12] ? 12 :
                  match1[13] ? 13 :
                  match1[14] ? 14 : 15; //若未找到使用15
assign s1_lowest_bit = tlb_ps4MB[s1_index] ? s1_vppn[8] : s1_va_bit12; //页号实际最低位与页大小相关
assign s1_ppn        = s1_lowest_bit ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
assign s1_ps         = tlb_ps4MB[s1_index] ? 6'd21 : 6'd12; //4MB:21 4KB:12
assign s1_plv        = s1_lowest_bit ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
assign s1_mat        = s1_lowest_bit ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
assign s1_d          = s1_lowest_bit ? tlb_d1  [s1_index] : tlb_d0  [s1_index];
assign s1_v          = s1_lowest_bit ? tlb_v1  [s1_index] : tlb_v0  [s1_index];

//match部分
genvar i;

for (i = 0; i < TLBNUM; i=i+1) begin
    assign match0[i] = (s0_vppn[18:9] == tlb_vppn[i][18:9]) //先考虑满足4MB的条件（低9位+省略的奇偶构成10位）
                    && (tlb_ps4MB[i] || s0_vppn[8:0] == tlb_vppn[i][8:0]) //再考虑满足4KB的条件
                    && ((s0_asid == tlb_asid[i]) || tlb_g[i]) && tlb_e[i]; //满足asid相同或者tlb_g置1，最后考虑当前位是否有效，tlb_e为1
    assign match1[i] = (s1_vppn[18:9] == tlb_vppn[i][18:9])
                    && (tlb_ps4MB[i] || s1_vppn[8:0] == tlb_vppn[i][8:0])
                    && ((s1_asid == tlb_asid[i]) || tlb_g[i]) && tlb_e[i];
end

//inv_match部分
wire [TLBNUM-1:0] G_is_0;
wire [TLBNUM-1:0] s1_asid_eq_ASID;
wire [TLBNUM-1:0] s1_vppn_match; //判断虚拟地址是否匹配需要同时参考vppn与ps域

genvar j;
for (j = 0; j < TLBNUM; j=j+1) begin
    assign G_is_0[j]           = !tlb_g[j];
    assign s1_asid_eq_ASID[j]  = (s1_asid == tlb_asid[j]); //判断asid是否相同
    assign s1_vppn_match[j] = tlb_ps4MB[j] ? s1_vppn[18:9] == tlb_vppn[j][18:9] :
                                             s1_vppn[18:0] == tlb_vppn[j][18:0];
    assign inv_match[j] = ((invtlb_op == 5'd0 || invtlb_op == 5'd1)
                        || (invtlb_op == 5'd2 && !G_is_0[k])
                        || (invtlb_op == 5'd3 &&  G_is_0[k])
                        || (invtlb_op == 5'd4 &&  G_is_0[k] && s1_asid_eq_ASID[k])
                        || (invtlb_op == 5'd5 &&  G_is_0[k] && s1_asid_eq_ASID[k] && s1_vppn_match[k])
                        || (invtlb_op == 5'd6 && !G_is_0[k] && s1_asid_eq_ASID[k] && s1_vppn_match[k]))
                        && invtlb_valid;
end

genvar k;
generate
for (k = 0; k < TLBNUM; k=k+1) begin
    always @(posedge clk) begin
        if  (inv_match[k])
            tlb_e[k] <= 1'b0; //注意此处tlb_e的赋值与写tlb事件冲突,但实际不会同时发生tlbinv与tlbwr事件
    end
end
endgenerate

endmodule