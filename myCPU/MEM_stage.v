`include "constants.h"

module MEM_stage(
    input   wire                          clk,
    input   wire                          reset,

    output wire        data_sram_en,
    output wire [3:0]  data_sram_we, 
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    input   wire                          WB_allow_in,
    input   wire [`to_MEM_data_width-1:0]  to_MEM_data,
    output  wire [`to_WB_data_width-1:0]   to_WB_data,
    input   wire                          EX_to_MEM_valid,
    output  wire                          MEM_to_WB_valid,
    output  wire                          MEM_allow_in
);

reg MEM_valid;
wire MEM_ready_go;

wire [31:0] alu_result;
wire [31:0] rkd_value;
wire        mem_we;
wire        res_from_mem;

assign MEM_ready_go = 1'b1;//无阻塞
assign MEM_allow_in = ~MEM_valid | (MEM_ready_go & WB_allow_in);
assign MEM_to_WB_valid = MEM_valid & MEM_ready_go;

always @(posedge clk) begin
    if (reset)
        MEM_valid <= 1'b0;
    else if (MEM_ready_go)
        MEM_valid <= EX_to_MEM_valid;
end

assign {alu_result,
        rkd_value,
        mem_we,
        res_from_mem,
        dest,
        gr_we} = to_MEM_data;

assign to_WB_data = {dest, //32
                     final_result, //32
                     gr_we //1
                    };                    

assign data_sram_en    = 1'b1;
assign data_sram_we    = {4{mem_we && MEM_valid}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

endmodule