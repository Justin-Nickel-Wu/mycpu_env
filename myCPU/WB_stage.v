`include "constants.h"

module WB_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire [`to_WB_data_width-1:0]  to_WB_data,
    input   wire                          MEM_to_WB_valid,
    output  wire                          WB_allow_in,

    output  wire                          rf_we,
    output  wire [4:0]                    rf_waddr,
    output  wire [31:0]                   rf_wdata,

    output wire  [31:0]                   debug_wb_pc,
    output wire  [ 3:0]                   debug_wb_rf_we,
    output wire  [ 4:0]                   debug_wb_rf_wnum,
    output wire  [31:0]                   debug_wb_rf_wdata,

    output wire  [`forwrd_data_width-1:0] WB_forward,

    output wire                           wb_ex,
    output wire  [ 5:0]                   wb_ecode,
    output wire  [ 8:0]                   wb_esubcode,
    output wire  [31:0]                   wb_pc
);

reg WB_valid;
wire WB_ready_go;
reg [`to_WB_data_width-1:0] to_WB_data_r;

wire [31:0] pc;
wire [ 4:0] dest;
wire [31:0] final_result;
wire        gr_we;
wire        ex_SYS;

wire [4:0] WB_dest;

assign WB_ready_go = 1'b1;//无阻塞
assign WB_allow_in = ~WB_valid | WB_ready_go;

always @(posedge clk) begin
    if (reset | wb_ex)
        WB_valid <= 1'b0;
    else if (WB_allow_in)
        WB_valid <= MEM_to_WB_valid;

    if (MEM_to_WB_valid && WB_allow_in)
            to_WB_data_r = to_WB_data;
end

assign {pc,
        dest,
        final_result,
        gr_we,
        ex_SYS} = to_WB_data_r;

assign rf_we    = gr_we && WB_valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;

assign wb_ex = ex_SYS & WB_valid;
assign wb_ecode = ex_SYS ? 6'hb : 6'h0;
assign wb_esubcode = ex_SYS ? 9'h0 : 9'h0;
assign wb_pc = pc;

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = dest;
assign debug_wb_rf_wdata = final_result;

assign WB_dest = dest & {5{WB_valid}};
assign WB_forward = {WB_dest, rf_wdata};

endmodule