`include "constants.h"

module EX_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire                          MEM_allow_in,
    input   wire [`to_EX_data_width-1:0]   to_EX_data,
    output  wire [`to_MEM_data_width-1:0]  to_MEM_data,
    input   wire                          ID_to_EX_valid,
    output  wire                          EX_to_MEM_valid,
    output  wire                          EX_allow_in,

    output  wire                          data_sram_en,
    output  wire [3:0]                    data_sram_we,
    output  wire [31:0]                   data_sram_addr,
    output  wire [31:0]                   data_sram_wdata,

    output  wire [`forwrd_data_width-1:0] EX_forward
);

reg                          EX_valid;
wire                         EX_ready_go;
reg  [`to_EX_data_width-1:0]  to_EX_data_r;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [31:0] pc;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [11:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        mem_we;
wire        res_from_mem;
wire [4:0]  dest;
wire        gr_we;

wire [4:0] EX_dest;

assign EX_ready_go = 1'b1;//无阻塞
assign EX_allow_in = ~EX_valid | (EX_ready_go & MEM_allow_in);
assign EX_to_MEM_valid = EX_valid & EX_ready_go;

always @(posedge clk) begin
    if (reset)
        EX_valid <= 1'b0;
    else if (EX_ready_go)
        EX_valid <= ID_to_EX_valid;

    if (ID_to_EX_valid && EX_allow_in)
            to_EX_data_r = to_EX_data;
end

assign {pc,
        rj_value,
        rkd_value,
        imm,
        alu_op,
        src1_is_pc,
        src2_is_imm,
        mem_we,
        res_from_mem,
        dest,
        gr_we} = to_EX_data_r;

assign to_MEM_data = {pc, //32
                      alu_result, //32
                      res_from_mem,//1
                      dest, //5
                      gr_we //1
                    };

assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign data_sram_en    = 1'b1;
assign data_sram_we    = {4{mem_we && EX_valid}};
assign data_sram_addr = alu_result;
assign data_sram_wdata = rkd_value;

assign EX_dest = dest & {5{EX_valid}} & {5{~res_from_mem}};  //如果为读内存指令，此处前递无意义，所以将EX_dest清为0
assign EX_forward = {EX_dest, alu_result};

/*
//输出写内存信息
always @(posedge clk) begin
    if (data_sram_we == 4'b1111)
        $display("WRITE MEM, pc: %8h, addr: %8h, data: %8h",pc, alu_result, rkd_value);
end
*/

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
);

endmodule