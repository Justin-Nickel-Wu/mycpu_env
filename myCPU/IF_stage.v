`ifdef XILINX_SIMULATOR
  `include "constants.h"
`elsif XILINX_SYNTHESIS
  `include "constants.h"
`else
 `include "myCPU/constants.h"
`endif

module IF_stage(
    input   wire                        clk,
    input   wire                        reset,

    input   wire                        wb_ex,
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

//控制阻塞信号
assign IF_ready_go = 1'b1;//无阻塞
assign IF_allow_in = ~IF_valid | (IF_ready_go & ID_allow_in);
assign IF_to_ID_valid = IF_valid & IF_ready_go;

always @(posedge clk) begin
    if (reset | wb_ex)
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
assign seq_pc       = pc + 3'h4;
assign nextpc       = wb_ex    ? ex_entry  :
                      br_taken ? br_target : 
                                 seq_pc;

//读inst_sram

assign inst_sram_en = to_IF_valid & IF_allow_in;//读nextpc地址，所以判断输入数据是否有效
assign inst_sram_we = {4{1'b0}};
assign inst_sram_addr = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst = inst_sram_rdata;

//传递数据
assign to_ID_data = {pc, inst};//{32, 32}

endmodule