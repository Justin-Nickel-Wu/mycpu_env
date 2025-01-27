`include "constants.h"

module EX_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire                          MEM_allow_in,
    input   wire [to_EX_data_width-1:0]   to_EX_data,
    output  wire [to_MEM_data_width-1:0]  to_MEM_data,
    output  wire                          EX_to_MEM_valid,
    output  wire                          EX_allow_in
);

reg EX_valid;
wire EX_ready_go;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire mem_we;
wire res_from_mem;

assign EX_ready_go = 1'b1;//无阻塞
assign EX_allow_in = ~EX_valid | (EX_ready_go & MEM_allow_in);
assign EX_to_MEM_valid = EX_valid & EX_ready_go;

always @(posedge clk) begin
    if (reset)
        EX_valid <= 1'b0;
    else if (EX_ready_go)
        EX_valid <= ID_to_EX_valid;
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
        gr_we} = to_EX_data;

assign to_MEM_data = {alu_result, //32
                      rkd_value, //32
                      mem_we, //1
                      res_from_mem//1
                      dest, //32
                      gr_we //1
                    };

assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
);

endmodule