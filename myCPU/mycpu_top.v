`include "constants.h"

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we, 
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

wire reset;

wire to_IF_valid;
wire to_ID_valid;
wire to_EX_valid;
wire to_MEM_valid;

wire ID_allow_in;
wire EX_allow_in;
wire MEM_allow_in;
wire WB_allow_in;

wire to_IF_valid;
wire IF_to_ID_valid;
wire ID_to_EX_valid;
wire EX_to_MEM_valid;
wire MEM_to_WB_valid;

wire [`to_ID_data_width-1:0] to_ID_data;
wire [`to_EX_data_width-1:0] to_EX_data;
wire [`to_MEM_data_width-1:0] to_MEM_data;
wire [`to_WB_data_width-1:0] to_WB_data;
wire [31:0] nextpc;

assign reset = ~resetn;

assign to_IF_valid = resetn;//

IF_stage u_IF_stage(
    .clk            (clk),
    .reset          (reset),
    .inst_sram_en   (inst_sram_en),
    .inst_sram_we   (inst_sram_we),
    .inst_sram_addr (inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .to_IF_valid    (to_IF_valid),
    .ID_allow_in    (ID_allow_in),
    .IF_to_ID_valid (IF_to_ID_valid),
    .to_ID_data     (to_ID_data),
    .nextpc         (nextpc)
);

ID_stage u_ID_stage(
    .clk            (clk),
    .reset          (reset),
    .to_ID_data     (to_ID_data),
    .EX_allow_in    (EX_allow_in),
    .to_EX_data     (to_EX_data),
    .nextpc         (nextpc),
//    .to_IF_valid   (to_IF_valid),
    .IF_to_ID_valid (IF_to_ID_valid),
    .ID_to_EX_valid (ID_to_EX_valid),
    .ID_allow_in    (ID_allow_in)
);

EX_stage u_EX_stage(
    .clk            (clk),
    .reset          (reset),
    .MEM_allow_in   (MEM_allow_in),
    .to_EX_data     (to_EX_data),
    .to_MEM_data    (to_MEM_data),
    .ID_to_EX_valid (ID_to_EX_valid),
    .EX_to_MEM_valid(EX_to_MEM_valid),
    .EX_allow_in    (EX_allow_in)
);

MEM_stage u_MEM_stage(
    .clk            (clk),
    .reset          (reset),
    .data_sram_en   (data_sram_en),
    .data_sram_we   (data_sram_we),
    .data_sram_addr (data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_rdata(data_sram_rdata),
    .WB_allow_in    (WB_allow_in),
    .to_MEM_data    (to_MEM_data),
    .to_WB_data     (to_WB_data),
    .EX_to_MEM_valid(EX_to_MEM_valid),
    .MEM_to_WB_valid(MEM_to_WB_valid),
    .MEM_allow_in   (MEM_allow_in)
);

WB_stage u_WB_stage(
    .clk            (clk),
    .reset          (resetn),

    .to_WB_data     (to_WB_data),
    .MEM_to_WB_valid(MEM_to_WB_valid),
    .WB_allow_in    (WB_allow_in),

    .debug_wb_pc       (debug_wb_pc),
    .debug_wb_rf_we    (debug_wb_rf_we),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum),
    .debug_wb_rf_wdata (debug_wb_rf_wdata)
);

endmodule