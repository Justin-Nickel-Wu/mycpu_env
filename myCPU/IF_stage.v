`include "constants.h"

module IF_stage(
    input   wire                         clk,
    input   wire                         reset,
    input   wire                         csr_reset,

    input   wire [31:0]                  inst_sram_rdata,

    output  wire                         IF_allow_in,
    input   wire                         preIF_to_IF_valid,
    input   wire                         ID_allow_in,
    output  wire                         IF_to_ID_valid,
    input   wire [`to_IF_data_width-1:0] to_IF_data,
    output  wire [`to_ID_data_width-1:0] to_ID_data
);

reg  IF_valid;
wire IF_ready_go;
reg  [`to_IF_data_width-1:0] to_IF_data_r;

wire [31:0] pc;
wire [31:0] inst;
wire        ex_ADEF;

//控制阻塞信号
assign IF_ready_go = 1'b1;//无阻塞
assign IF_allow_in = ~IF_valid | (IF_ready_go & ID_allow_in) | csr_reset; //csr_reset后要允许preIF进入
assign IF_to_ID_valid = IF_valid & IF_ready_go;

always @(posedge clk) begin
    if (reset) //此处在csr_reset后一定能接收到preIF的取值
        IF_valid <= 1'b0;
    else if (IF_allow_in)
        IF_valid <= preIF_to_IF_valid;

    if (preIF_to_IF_valid && IF_allow_in)
        to_IF_data_r <= to_IF_data;
end

assign ex_ADEF      = pc[1:0] != 2'b00;

//读inst_sram
assign pc = to_IF_data_r[31:0];
assign inst = ex_ADEF ? 32'b0:  
                        inst_sram_rdata; //地址无效赋全0
//TODO：赋全0后续会被标记上指令不存在例外，这样是否会出现问题？

//传递数据
assign to_ID_data = {pc, 
                     inst,
                     ex_ADEF};

endmodule