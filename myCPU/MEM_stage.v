`include "constants.h"

module MEM_stage(
    input   wire                          clk,
    input   wire                          reset,

    input  wire [31:0] data_sram_rdata,

    input   wire                          WB_allow_in,
    input   wire [`to_MEM_data_width-1:0]  to_MEM_data,
    output  wire [`to_WB_data_width-1:0]   to_WB_data,
    input   wire                          EX_to_MEM_valid,
    output  wire                          MEM_to_WB_valid,
    output  wire                          MEM_allow_in,

    output  wire [`forwrd_data_width-1:0] MEM_forward
);

reg                           MEM_valid;
wire                          MEM_ready_go;
reg  [`to_MEM_data_width-1:0] to_MEM_data_r;

wire [31:0] pc;
wire [31:0] alu_result;
wire        res_from_mem;
wire [4:0]  dest;
wire        gr_we;

wire [31:0] mem_result;
wire [31:0] final_result;

wire [4:0]  MEM_dest;

assign MEM_ready_go = 1'b1;//无阻塞
assign MEM_allow_in = ~MEM_valid | (MEM_ready_go & WB_allow_in);
assign MEM_to_WB_valid = MEM_valid & MEM_ready_go;

always @(posedge clk) begin
    if (reset)
        MEM_valid <= 1'b0;
    else if (MEM_ready_go)
        MEM_valid <= EX_to_MEM_valid;

    if (EX_to_MEM_valid && MEM_allow_in)
            to_MEM_data_r = to_MEM_data;
end

assign {pc,
        alu_result,
        res_from_mem,
        dest,
        gr_we} = to_MEM_data_r;

assign to_WB_data = {pc,//32
                     dest, //5
                     final_result, //32
                     gr_we //1
                    };                    

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

assign MEM_dest = dest & {5{MEM_valid}};
assign MEM_forward = {MEM_dest, final_result};


endmodule