`include "constants.h"

module preIF_stage(
    input  wire                         clk,
    input  wire                         reset,

    output wire                         preIF_to_IF_valid,
    input  wire                         IF_allow_in,
    
    output wire                         inst_sram_en,
    output wire [ 3:0]                  inst_sram_we,
    output wire [31:0]                  inst_sram_addr,
    output wire [31:0]                  inst_sram_wdata,

    input wire                          csr_reset,
    input wire [31:0]                   ex_entry,

    input  wire [`br_data_width-1:0]    br_data,
    output wire [`to_IF_data_width-1:0] to_IF_data
);

wire preIF_valid;
wire preIF_ready_go;

reg  [31:0] pc;
wire [31:0] nextpc;
wire [31:0] seq_pc;
wire        br_taken;
wire [31:0] br_target;

assign preIF_valid = ~reset;//非重置状态，preIF总是发出读请求
assign preIF_ready_go = IF_allow_in;//IF允许输入即发射
assign preIF_to_IF_valid = preIF_valid && preIF_ready_go;//当preIF有效并且准备发射是为真

always @(posedge clk) begin
    if (reset)
        pc <= 32'h1bfffffc;//使重置后的pc为0x1c000000
    else if (IF_allow_in)
        pc <= nextpc;
end

assign to_IF_data = nextpc;//送往IF的是读nextpc地址处的指令，故此处使用nextpc

assign {br_taken, br_target} = br_data;
assign seq_pc       = pc + 32'h4;
assign nextpc       = csr_reset ? ex_entry  :
                      br_taken  ? br_target : 
                                  seq_pc;

assign inst_sram_en = csr_reset || (preIF_valid && IF_allow_in);//读指令使能相当于控制是否向后发射新的inst，下一级流水需准备好才可接受。csr_reset时强制发射。
assign inst_sram_we = {4{1'b0}};
assign inst_sram_addr = nextpc;
assign inst_sram_wdata = 32'b0;

endmodule