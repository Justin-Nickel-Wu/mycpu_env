`include "constants.h"

module IF_stage(
    input   wire                        clk,
    input   wire                        reset,

    input   wire                        csr_reset,
    input   wire [31:0]                 ex_entry,

    output  wire                        inst_sram_en,
    output  wire [ 3:0]                  inst_sram_we,
    output  wire [31:0]                 inst_sram_addr,
    output  wire [31:0]                 inst_sram_wdata,
    input   wire [31:0]                 inst_sram_rdata,

    input   wire                         to_IF_valid,
    input   wire                         ID_allow_in,
    output  wire                         IF_to_ID_valid,
    output  wire [`to_ID_data_width-1:0] to_ID_data,
    input   wire [`br_data_width-1:0]    br_data
);

reg  IF_valid;
wire IF_ready_go;
wire IF_allow_in;

reg  [31:0] pc;
wire [31:0] inst;

wire [31:0] nextpc;
wire [31:0] seq_pc;
wire        br_taken;
wire [31:0] br_target;

wire        ex_ADEF;

//控制阻塞信号
assign IF_ready_go = 1'b1;//无阻塞
assign IF_allow_in = ~IF_valid | (IF_ready_go & ID_allow_in) | csr_reset;
assign IF_to_ID_valid = IF_valid & IF_ready_go;

always @(posedge clk) begin
    if (reset)
        IF_valid <= 1'b0;
    else if (IF_allow_in)
        IF_valid <= to_IF_valid;
end

//pc信号控制
always @(posedge clk) begin
    if (reset)
        pc <= 32'h1bfffffc;//使重置后的pc为0x1c000000
    else if (to_IF_valid && IF_allow_in)
        pc <= nextpc;
end

assign {br_taken, br_target} = br_data;
assign seq_pc       = pc + 32'h4;
assign nextpc       = csr_reset ? ex_entry  :
                      br_taken  ? br_target : 
                                  seq_pc;
assign ex_ADEF      = pc[1:0] != 2'b00;

//读inst_sram

assign inst_sram_en = to_IF_valid & IF_allow_in;//读nextpc地址，所以判断输入数据是否有效
assign inst_sram_we = {4{1'b0}};
assign inst_sram_addr = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst = ex_ADEF ? 32'b0:  
                        inst_sram_rdata; //地址无效赋全0
//TODO：赋全0后续会被标记上指令不存在例外，这样是否会出现问题？

//传递数据
assign to_ID_data = {pc, 
                     inst,
                     ex_ADEF};

endmodule