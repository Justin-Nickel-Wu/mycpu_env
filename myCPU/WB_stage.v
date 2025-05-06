`include "constants.vh"

module WB_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire                          csr_reset,

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
    output wire  [31:0]                   wb_vaddr,
    output wire  [31:0]                   wb_pc,
    output                                ertn_flush,
    input  wire  [ 1:0]                   csr_plv,

    output wire                           csr_re,
    output wire  [`CSR_NUM_WIDTH-1:0]     csr_num,
    input  wire  [31:0]                   csr_rvalue,
    output                                csr_we,
    output wire  [31:0]                   csr_wmask,
    output wire  [31:0]                   csr_wvalue,
    //TLB ins
    output wire                           tlbsrch_en,
    output wire                           data_tlb_found,
    output wire  [   $clog2(`TLBNUM)-1:0] data_tlb_index,

    output wire                           wb_wr_asid_tlbehi
);

reg WB_valid;
wire WB_ready_go;
reg [`to_WB_data_width-1:0] to_WB_data_r;

wire [31:0] pc;
wire [ 4:0] dest;
wire [31:0] final_result;
wire        gr_we;
wire        ex_INT;
wire        ex_SYS;
wire        ex_BRK;
wire        ex_ADEF;
wire        ex_ALE;
wire        ex_INE;
wire        is_etrn;
wire        op_csr;
wire        WB_op_csr;
wire        wb_csr_we;
wire [31:0] csr_wmask_tmp;
wire [ 4:0] rj;
wire [ 4:0] WB_dest;

assign WB_ready_go = 1'b1;//无阻塞
assign WB_allow_in = ~WB_valid | WB_ready_go;

always @(posedge clk) begin
    if (reset | wb_ex)
        WB_valid <= 1'b0;
    else if (WB_allow_in)
        WB_valid <= MEM_to_WB_valid;

    if (MEM_to_WB_valid && WB_allow_in)
            to_WB_data_r <= to_WB_data;
end

assign {pc,
        dest,
        final_result,
        gr_we,
        ex_INT,
        ex_SYS,
        ex_BRK,
        ex_ADEF,
        ex_ALE,
        ex_INE,
        is_etrn,
        op_csr,
        csr_num,
        wb_csr_we,
        csr_wmask_tmp,
        rj,
        tlbsrch_en,
        data_tlb_found,
        data_tlb_index} = to_WB_data_r;

assign rf_we    = gr_we && WB_valid && !wb_ex;
assign rf_waddr = dest;
assign rf_wdata = csr_re ? csr_rvalue : final_result;

assign csr_re = WB_valid && op_csr;
assign csr_we = WB_valid && wb_csr_we;
assign csr_wmask =  (rj == 5'b00001) ? 32'hffffffff : csr_wmask_tmp; 
assign csr_wvalue = final_result;
assign wb_wr_asid_tlbehi = WB_valid && wb_csr_we && (csr_num == `CSR_TLBEHI || csr_num == `CSR_ASID);

assign wb_ex = WB_valid && (ex_INT || ex_SYS || ex_BRK || 
                            ex_ADEF || ex_ALE || ex_INE || is_etrn);
assign wb_ecode = ex_SYS  ? 6'hb :
                  ex_BRK  ? 6'hc :
                  ex_ADEF ? 6'h8 : 
                  ex_ALE  ? 6'h9 : 
                  ex_INE  ? 6'hd : 
                            6'h0; //ex_INT
assign wb_esubcode = 9'h0; //暂时不存在其他可能性
assign wb_pc = pc;
assign wb_vaddr = final_result;
assign ertn_flush = is_etrn && WB_valid && (csr_plv == 2'b00);

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

assign WB_dest = dest & {5{WB_valid}};
assign WB_op_csr = op_csr & WB_valid;
assign WB_forward = {WB_dest, rf_wdata, WB_op_csr};

endmodule