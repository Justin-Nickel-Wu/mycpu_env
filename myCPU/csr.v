`ifdef XILINX_SIMULATOR
  `include "constants.h"
`elsif XILINX_SYNTHESIS
  `include "constants.h"
`else
 `include "myCPU/constants.h"
`endif

module CSR_module(
    input  wire                       clk,
    input  wire                       reset,

    input  wire                       csr_re,       //读使能
    input  wire  [`CSR_NUM_WIDTH-1:0] csr_num,      //寄存器号
    output wire                [31:0] csr_rvalue,   //寄存器读返回值
    input  wire                       csr_we,       //写使能
    input  wire                [31:0] csr_wmask,    //写掩码
    input  wire                [31:0] csr_wvalue,   //写数据

    input  wire                       ex_entry,
    input  wire                       ertn_flush,
    input  wire                       wb_ex,
    input  wire                [31:0] wb_pc,
    input  wire                [ 5:0] wb_ecode,
    input  wire                [ 8:0] wb_esubcode
);

assign csr_rvalue = ~csr_re                ? 32'b0      :
                    csr_num == `CSR_CRMD   ? csr_crmd   :
                    csr_num == `CSR_PRMD   ? csr_prmd   :
                    csr_num == `CSR_ESTAT  ? csr_estat  :
                    csr_num == `CSR_ERA    ? csr_era    :
                    csr_num == `CSR_EENTRY ? csr_eentry :
                    csr_num == `CSR_SAVE0  ? csr_save0  :
                    csr_num == `CSR_SAVE1  ? csr_save1  :
                    csr_num == `CSR_SAVE2  ? csr_save2  :
                    csr_num == `CSR_SAVE3  ? csr_save3  : 32'b0;

/*-----------------------------*/
/*CRMD*/
reg  [ 1:0] csr_crmd_plv;
reg         csr_crmd_ie;
wire        csr_crmd_da;
wire        csr_crmd_pg;
wire [ 1:0] csr_crmd_datf;
wire [ 1:0] csr_crmd_datm;
wire [31:0] csr_crmd;

assign csr_crmd = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

//PLV
always @(posedge clk) begin
    if (reset)
        csr_crmd_plv <= 2'b00;
    else if (wb_ex)
        csr_crmd_plv <= 2'b00;
    else if (ertn_flush)
        csr_crmd_plv <= csr_prmd_pplv;
    else if (csr_we && csr_num == `CSR_CRMD)
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                     | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
end
//IE
always @(posedge clk) begin
    if (reset)
        csr_crmd_ie <= 1'b0;
    else if (wb_ex)
        csr_crmd_ie <= 1'b0;
    else if (ertn_flush)
        csr_crmd_ie <= csr_prmd_pie;
    else if (csr_we && csr_num == `CSR_CRMD)
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                    | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
end
//DA PG DATF DATM need to do
assign csr_crmd_da   = 1'b1;
assign csr_crmd_pg   = 1'b0;
assign csr_crmd_datf = 2'b00;
assign csr_crmd_datm = 2'b00;

/*-----------------------------*/
/*PRMD*/
reg  [ 1:0] csr_prmd_pplv;
reg         csr_prmd_pie;
wire [31:0] csr_prmd;

assign csr_prmd = {29'b0, csr_prmd_pie, csr_prmd_pplv};

//PPLV PIE
always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end
    else if (csr_we && csr_num == `CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                      | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                      | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
    end
end

/*-----------------------------*/
/*ESTAT*/
reg  [12:0] csr_estat_is;
reg  [ 5:0] csr_estat_ecode;
reg  [ 8:0] csr_estat_esubcode;
wire [31:0] csr_estat;

assign csr_estat = {1'b0, wb_esubcode, wb_ecode, 3'b0, csr_estat_is};

//IS
always @(posedge clk) begin
    if (reset)
        csr_estat_is[`CSR_ESTAT_IS10] <= 2'b00;
    else if (csr_we && csr_num == `CSR_ESTAT)
        csr_estat_is[`CSR_ESTAT_IS10] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                                      | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[`CSR_ESTAT_IS10];
/*don't need to work now
    csr_estat_is[9:2] <= hw_int_in[7:0];

    csr_estat_is[10] <= 1'b0;

    if (timer_cnt[31:0] == 0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;

    csr_estat_is[12] <= ipi_int_in; 
*/
end
//ECODE ESUBCODE
always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

/*-----------------------------*/
/*ERA*/
reg  [31:0] csr_era_pc;
wire [31:0] csr_era;

assign csr_era = csr_era_pc;

//PC
always @(posedge clk) begin
    if (wb_ex)
        csr_era_pc <= wb_pc;
    else if (csr_we && csr_num == `CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                   | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;    
end

/*-----------------------------*/
/*EENTRY*/
reg  [25:0] csr_eentry_va;
wire [31:0] csr_eentry;

assign csr_eentry = {csr_eentry_va, 6'b0};
//VA
always @(posedge clk) begin
    if (csr_we && csr_num == `CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                      | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
end

/*-----------------------------*/
/*SAVE*/
reg  [31:0] csr_save0_data;
reg  [31:0] csr_save1_data;
reg  [31:0] csr_save2_data;
reg  [31:0] csr_save3_data;
wire [31:0] csr_save0;
wire [31:0] csr_save1;
wire [31:0] csr_save2;
wire [31:0] csr_save3;

assign csr_save0 = csr_save0_data;
assign csr_save1 = csr_save1_data;
assign csr_save2 = csr_save2_data;
assign csr_save3 = csr_save3_data;

//SAVE0 SAVE1 SAVE2 SAVE3
always @(posedge clk) begin
    if (csr_we && csr_num == `CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
    if (csr_we && csr_num == `CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
    if (csr_we && csr_num == `CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
    if (csr_we && csr_num == `CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
end

endmodule