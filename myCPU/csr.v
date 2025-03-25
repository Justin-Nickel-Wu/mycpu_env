`include "constants.h"

module CSR_module(
    input  wire                       clk,
    input  wire                       reset,

    input  wire                       csr_re,       //读使能
    input  wire  [`CSR_NUM_WIDTH-1:0] csr_num,      //寄存器号
    output wire                [31:0] csr_rvalue,   //寄存器读返回值
    input  wire                       csr_we,       //写使能
    input  wire                [31:0] csr_wmask,    //写掩码
    input  wire                [31:0] csr_wvalue,   //写数据

    input  wire                [ 7:0] hw_int_in,
    input  wire                       ipi_int_in,
    output wire                       has_int,
    output wire                [31:0] ex_entry,
    output wire                       csr_reset,
    input  wire                       ertn_flush,
    input  wire                       wb_ex_with_ertn, //从CPU内核传入的例外包含了etrn，但实际上是不包含的，处理相关流程需注意。
    input  wire                [31:0] wb_pc,
    input  wire                [31:0] wb_vaddr,
    input  wire                [ 5:0] wb_ecode,
    input  wire                [ 8:0] wb_esubcode,
    output wire                [ 1:0] csr_plv
);

wire        wb_ex;

//CRMD
reg  [ 1:0] csr_crmd_plv;
reg         csr_crmd_ie;
wire        csr_crmd_da;
wire        csr_crmd_pg;
wire [ 1:0] csr_crmd_datf;
wire [ 1:0] csr_crmd_datm;
wire [31:0] csr_crmd;
//PRMD
reg  [ 1:0] csr_prmd_pplv;
reg         csr_prmd_pie;
wire [31:0] csr_prmd;
//ECFG
reg  [12:0] csr_ecfg_lie;
wire [31:0] csr_ecfg;
//ESTAT
reg  [12:0] csr_estat_is;
reg  [ 5:0] csr_estat_ecode;
reg  [ 8:0] csr_estat_esubcode;
wire [31:0] csr_estat;
//ERA
reg  [31:0] csr_era_pc;
wire [31:0] csr_era;
//BADV
reg  [31:0] csr_badv_vaddr;
wire [31:0] csr_badv;
wire wb_ex_addr_err;
//EENTRY
reg  [25:0] csr_eentry_va;
wire [31:0] csr_eentry;
//SAVE
reg  [31:0] csr_save0_data;
reg  [31:0] csr_save1_data;
reg  [31:0] csr_save2_data;
reg  [31:0] csr_save3_data;
wire [31:0] csr_save0;
wire [31:0] csr_save1;
wire [31:0] csr_save2;
wire [31:0] csr_save3;
//TID
reg  [31:0] csr_tid_tid;
wire [31:0] csr_tid;
wire [31:0] coreid_in;
//TCFG
reg         csr_tcfg_en;
reg         csr_tcfg_periodic;
reg  [29:0] csr_tcfg_initval;
wire [31:0] csr_tcfg;
//TVAL
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg  [31:0] timer_cnt;
//TICLR
wire [31:0] csr_ticlr;

assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);
assign wb_ex = wb_ex_with_ertn && ~ertn_flush;

assign csr_rvalue = ~csr_re                ? 32'b0      :
                    csr_num == `CSR_CRMD   ? csr_crmd   :
                    csr_num == `CSR_PRMD   ? csr_prmd   :
                    csr_num == `CSR_ECFG   ? csr_ecfg   :
                    csr_num == `CSR_ESTAT  ? csr_estat  :
                    csr_num == `CSR_ERA    ? csr_era    :
                    csr_num == `CSR_BADV   ? csr_badv   :
                    csr_num == `CSR_EENTRY ? csr_eentry :
                    csr_num == `CSR_SAVE0  ? csr_save0  :
                    csr_num == `CSR_SAVE1  ? csr_save1  :
                    csr_num == `CSR_SAVE2  ? csr_save2  :
                    csr_num == `CSR_SAVE3  ? csr_save3  : 
                    csr_num == `CSR_TID    ? csr_tid    :
                    csr_num == `CSR_TCFG   ? csr_tcfg   :
                    csr_num == `CSR_TVAL   ? csr_tval   : 32'b0;
assign ex_entry = ertn_flush ? csr_era :
           /*not ertn_flush*/  csr_eentry;
assign csr_reset = wb_ex || ertn_flush;
assign csr_plv = csr_crmd_plv;

/*-----------------------------*/
/*CRMD*/

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
/*ECFG*/

assign csr_ecfg = {19'b0, csr_ecfg_lie};

//LIE
always @(posedge clk) begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num == `CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE] & 13'b1_1011_1111_1111
                     | ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
end

/*-----------------------------*/
/*ESTAT*/

assign csr_estat = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
//1 6 9 3 13
//IS
always @(posedge clk) begin
    if (reset)
        csr_estat_is[`CSR_ESTAT_IS10] <= 2'b00;
    else if (csr_we && csr_num == `CSR_ESTAT)
        csr_estat_is[`CSR_ESTAT_IS10] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                                      | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[`CSR_ESTAT_IS10];

    // csr_estat_is[12:2] <= 11'b0;

    csr_estat_is[9:2] <= hw_int_in[7:0];

    csr_estat_is[10] <= 1'b0;

    if (timer_cnt[31:0] == 0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;

    csr_estat_is[12] <= ipi_int_in; 
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
/*BADV*/

assign csr_badv = csr_badv_vaddr;
assign wb_ex_addr_err = (wb_ecode == `ECODE_ADE) || (wb_ecode == `ECODE_ALE);

//VADDR
always @(posedge clk) begin
    if (wb_ex && wb_ex_addr_err)
        csr_badv_vaddr <= (wb_ecode == `ECODE_ADE && wb_esubcode == `ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
    else if (csr_we && csr_num == `CSR_BADV)
        csr_badv_vaddr <= csr_wmask[`CSR_BADV_VADDR] & csr_wvalue[`CSR_BADV_VADDR]
                       | ~csr_wmask[`CSR_BADV_VADDR] & csr_badv_vaddr;
end

/*-----------------------------*/
/*EENTRY*/

assign csr_eentry = {csr_eentry_va, 6'b0};
//VA
always @(posedge clk) begin
    if (csr_we && csr_num == `CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                      | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
end

/*-----------------------------*/
/*SAVE*/

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

/*-----------------------------*/
/*TID*/

assign csr_tid = csr_tid_tid;
assign coreid_in = 32'h12345678;

//TID
always @(posedge clk) begin
    if (reset)
        csr_tid_tid <= coreid_in;
    else if (csr_we && csr_num == `CSR_TID)
        csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                    | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
end

/*-----------------------------*/
/*TCFG*/

assign csr_tcfg = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

//EN PERIODIC INITVAL
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_num == `CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                    | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
    
    if (csr_we && csr_num == `CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIODIC] & csr_wvalue[`CSR_TCFG_PERIODIC]
                          | ~csr_wmask[`CSR_TCFG_PERIODIC] & csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITVAL] & csr_wvalue[`CSR_TCFG_INITVAL]
                         | ~csr_wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initval;
    end
end

/*-----------------------------*/
/*TVAL*/

assign csr_tval = timer_cnt;
assign tcfg_next_value = csr_wmask & csr_wvalue
                      | ~csr_wmask & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
        if (timer_cnt == 32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
end

/*-----------------------------*/
/*TICLR*/

assign csr_ticlr = 32'b0;

endmodule