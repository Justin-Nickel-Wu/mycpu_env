`ifdef XILINX_SIMULATOR
  `include "constants.h"
`elsif XILINX_SYNTHESIS
  `include "constants.h"
`else
 `include "myCPU/constants.h"
`endif

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

wire ID_allow_in;
wire EX_allow_in;
wire MEM_allow_in;
wire WB_allow_in;

wire to_IF_valid;
wire IF_to_ID_valid;
wire ID_to_EX_valid;
wire EX_to_MEM_valid;
wire MEM_to_WB_valid;

wire [`to_ID_data_width-1  :0]   to_ID_data;
wire [`to_EX_data_width-1  :0]   to_EX_data;
wire [`to_MEM_data_width-1 :0]   to_MEM_data;
wire [`to_WB_data_width-1  :0]   to_WB_data;
wire [`br_data_width-1     :0]   br_data;

wire [ 4:0]  rf_raddr1;
wire [31:0]  rf_rdata1;
wire [ 4:0]  rf_raddr2;
wire [31:0]  rf_rdata2;
wire         rf_we;
wire [ 4:0]  rf_waddr;
wire [31:0]  rf_wdata;

wire [37:0]                    EX_forward;
wire [`forwrd_data_width-1:0]  MEM_forward;
wire [`forwrd_data_width-1:0]  WB_forward;

wire        wb_ex;
wire [ 5:0] wb_ecode;
wire [ 8:0] wb_esubcode;
wire [31:0] wb_pc;
wire [31:0] ex_entry;

assign reset = ~resetn;

assign to_IF_valid = resetn;

IF_stage u_IF_stage(
    .clk            (clk),
    .reset          (reset),

    .wb_ex          (wb_ex),
    .ex_entry       (ex_entry),

    .inst_sram_en   (inst_sram_en),
    .inst_sram_we   (inst_sram_we),
    .inst_sram_addr (inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),

    .to_IF_valid    (to_IF_valid),
    .ID_allow_in    (ID_allow_in),
    .IF_to_ID_valid (IF_to_ID_valid),
    .to_ID_data     (to_ID_data),
    .br_data         (br_data)
);

ID_stage u_ID_stage(
    .clk            (clk),
    .reset          (reset),

    .wb_ex          (wb_ex),

    .to_ID_data     (to_ID_data),
    .EX_allow_in    (EX_allow_in),
    .to_EX_data     (to_EX_data),
//    .to_IF_valid   (to_IF_valid),
    .IF_to_ID_valid (IF_to_ID_valid),
    .ID_to_EX_valid (ID_to_EX_valid),
    .ID_allow_in    (ID_allow_in),
    .br_data        (br_data),

    .rf_raddr1      (rf_raddr1),
    .rf_rdata1      (rf_rdata1),
    .rf_raddr2      (rf_raddr2),
    .rf_rdata2      (rf_rdata2),

    .EX_forward     (EX_forward),
    .MEM_forward    (MEM_forward),
    .WB_forward     (WB_forward)
);

EX_stage u_EX_stage(
    .clk            (clk),
    .reset          (reset),
    .wb_ex          (wb_ex),

    .MEM_allow_in   (MEM_allow_in),
    .to_EX_data     (to_EX_data),
    .to_MEM_data    (to_MEM_data),
    .ID_to_EX_valid (ID_to_EX_valid),
    .EX_to_MEM_valid(EX_to_MEM_valid),
    .EX_allow_in    (EX_allow_in),

    .data_sram_en   (data_sram_en),
    .data_sram_we   (data_sram_we),
    .data_sram_addr (data_sram_addr),
    .data_sram_wdata(data_sram_wdata),

    .EX_forward     (EX_forward)
);

MEM_stage u_MEM_stage(
    .clk            (clk),
    .reset          (reset),
    
    .wb_ex          (wb_ex),

    .data_sram_rdata(data_sram_rdata),

    .WB_allow_in    (WB_allow_in),
    .to_MEM_data    (to_MEM_data),
    .to_WB_data     (to_WB_data),
    .EX_to_MEM_valid(EX_to_MEM_valid),
    .MEM_to_WB_valid(MEM_to_WB_valid),
    .MEM_allow_in   (MEM_allow_in),

    .MEM_forward    (MEM_forward)
);

WB_stage u_WB_stage(
    .clk            (clk),
    .reset          (reset),

    .to_WB_data     (to_WB_data),
    .MEM_to_WB_valid(MEM_to_WB_valid),
    .WB_allow_in    (WB_allow_in),

    .rf_we          (rf_we),
    .rf_waddr       (rf_waddr),
    .rf_wdata       (rf_wdata),

    .debug_wb_pc       (debug_wb_pc),
    .debug_wb_rf_we    (debug_wb_rf_we),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum),
    .debug_wb_rf_wdata (debug_wb_rf_wdata),

    .WB_forward        (WB_forward),

    .wb_ex             (wb_ex),
    .wb_ecode          (wb_ecode),
    .wb_esubcode       (wb_esubcode),
    .wb_pc             (wb_pc)
);

CSR_module u_CSR_module(
    .clk                      (clk),
    .reset                    (reset),

    .csr_re(),
    .csr_num(),
    .csr_rvalue(),
    .csr_we(),
    .csr_wmask(),
    .csr_wvalue(),

    .ex_entry                 (ex_entry),
    .ertn_flush(),
    .wb_ex                    (wb_ex),
    .wb_pc                    (wb_pc),
    .wb_ecode                 (wb_ecode),
    .wb_esubcode              (wb_esubcode)
);

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

endmodule