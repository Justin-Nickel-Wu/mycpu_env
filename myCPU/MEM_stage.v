`include "constants.vh"

module MEM_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire                          csr_reset,
    output  wire                          mem_ex,

    input   wire                          data_sram_data_ok,
    input   wire [31:0]                   data_sram_rdata,

    input   wire [31:0]                   cntvl,
    input   wire [31:0]                   cntvh,

    input   wire                          WB_allow_in,
    input   wire [`to_MEM_data_width-1:0] to_MEM_data,
    output  wire [`to_WB_data_width-1 :0] to_WB_data,
    input   wire                          EX_to_MEM_valid,
    output  wire                          MEM_to_WB_valid,
    output  wire                          MEM_allow_in,

    output  wire [`forwrd_data_width  :0] MEM_forward,
    //to EX
    output  wire                          mem_wr_asid_tlbehi
);

reg                           MEM_valid;
wire                          MEM_ready_go;
reg  [`to_MEM_data_width-1:0] to_MEM_data_r;

wire [31:0] pc;
wire [31:0] alu_result;
wire [4:0]  dest;
wire        gr_we;
wire        rdcntvh;
wire        rdcntvl;
wire        tlbsrch_en;

wire        ex_INT;
wire        ex_SYS;
wire        ex_BRK;
wire        ex_ADEF;
wire        ex_ALE;
wire        ex_INE;
wire        is_ertn;

wire        res_from_mem;
wire        read_mem_1_byte;
wire        read_mem_2_byte;
wire        read_mem_4_byte;
wire        read_mem_is_signed;
wire        data_sram_en;
wire [ 1:0] read_mem_addr;
wire [ 7:0] mem_data_1_byte;
wire [15:0] mem_data_2_byte;
wire [31:0] final_mem_data_1_byte;
wire [31:0] final_mem_data_2_byte;
wire [31:0] final_mem_data;

wire [31:0] mem_data_4_byte;
wire [31:0] final_result;

wire [4:0]  MEM_dest;
wire        MEM_forward_wait;

wire op_csr;
wire MEM_op_csr;
wire [`CSR_NUM_WIDTH-1:0] csr_num;
wire csr_we;
wire [31:0] csr_wmask_tmp;
wire [4:0] rj;

wire                          data_tlb_found;
wire [   $clog2(`TLBNUM)-1:0] data_tlb_index;
wire [                  19:0] data_tlb_ppn;
wire [                   1:0] data_tlb_plv;
wire [                   1:0] data_tlb_mat;
wire                          data_tlb_d;
wire                          data_tlb_v;

/*
localparam IDLE = 0,
           WAIT = 1;

reg  MEM_state;

always @(posedge clk) begin
    if (reset || csr_reset) begin
        MEM_state <= IDLE;
    end else
        case (MEM_state)
            IDLE: begin
                if (data_sram_en) begin
                    if (data_sram_data_ok) begin
                        //向后发射，保持IDLE。能保证WB一定无阻塞。
                    end else begin 
                        MEM_state <= WAIT;
                    end
                end
            end

            WAIT: begin
                if (data_sram_data_ok)
                    MEM_state <= IDLE;
            end
        endcase
end
 TODO: 是否需要状态机？
*/

assign MEM_ready_go = ~data_sram_en || data_sram_data_ok;//无阻塞
assign MEM_allow_in = ~MEM_valid | (MEM_ready_go & WB_allow_in);
assign MEM_to_WB_valid = MEM_valid & MEM_ready_go;
assign mem_ex = MEM_valid && (ex_INT || ex_SYS || ex_BRK || 
                             ex_ADEF || ex_ALE || ex_INE ||is_ertn);

always @(posedge clk) begin
    if (reset | csr_reset)
        MEM_valid <= 1'b0;
    else if (MEM_allow_in)
        MEM_valid <= EX_to_MEM_valid;

    if (EX_to_MEM_valid && MEM_allow_in)
            to_MEM_data_r <= to_MEM_data;
end

assign {pc,
        alu_result,
        read_mem_1_byte,
        read_mem_2_byte,
        read_mem_4_byte,
        read_mem_is_signed,
        data_sram_en,
        dest,
        gr_we,
        ex_INT,
        ex_SYS,
        ex_BRK,
        ex_ADEF,
        ex_ALE,
        ex_INE,
        is_ertn,
        op_csr,
        csr_num,
        csr_we,
        csr_wmask_tmp,
        rj,
        rdcntvh,
        rdcntvl,
        tlbsrch_en} = to_MEM_data_r;

assign to_WB_data = {pc,//32
                     dest, //5
                     final_result, //32
                     gr_we, //1
                     ex_INT,
                     ex_SYS,
                     ex_BRK,
                     ex_ADEF,
                     ex_ALE,
                     ex_INE,
                     is_ertn,
                     op_csr,
                     csr_num,
                     csr_we,
                     csr_wmask_tmp,
                     rj,
                     tlbsrch_en,
                     data_tlb_found,
                     data_tlb_index
                    };                    

assign res_from_mem    = read_mem_1_byte | read_mem_2_byte | read_mem_4_byte;
assign read_mem_addr   = alu_result[1:0];
assign mem_data_4_byte = data_sram_rdata;
assign mem_data_1_byte = read_mem_addr == 2'b00 ? mem_data_4_byte[ 7: 0] :
                         read_mem_addr == 2'b01 ? mem_data_4_byte[15: 8] :
                         read_mem_addr == 2'b10 ? mem_data_4_byte[23:16] :
                       /*read_mem_addr == 2'b11*/ mem_data_4_byte[31:24];
assign mem_data_2_byte = read_mem_addr == 2'b00 ? mem_data_4_byte[15: 0] :
        /*only two case read_mem_addr == 2'b10*/  mem_data_4_byte[31:16];
assign final_mem_data_1_byte = read_mem_is_signed ? {{24{mem_data_1_byte[ 7]}}, mem_data_1_byte} : {24'b0, mem_data_1_byte};
assign final_mem_data_2_byte = read_mem_is_signed ? {{16{mem_data_2_byte[15]}}, mem_data_2_byte} : {16'b0, mem_data_2_byte};
assign final_mem_data        = read_mem_1_byte ? final_mem_data_1_byte :
                               read_mem_2_byte ? final_mem_data_2_byte :
                             /*read_mem_4_byte*/ mem_data_4_byte;

assign final_result = rdcntvh      ? cntvh : 
                      rdcntvl      ? cntvl :
                      ex_ALE       ? alu_result :
                      res_from_mem ? final_mem_data : 
                                     alu_result;

assign MEM_dest = dest & {5{MEM_valid}}; 
assign MEM_forward_wait = MEM_valid & ~MEM_ready_go; //如果未完成等待，需要阻塞ID阶段
assign MEM_op_csr = op_csr && MEM_valid;
assign MEM_forward = {MEM_dest, MEM_forward_wait, final_result, MEM_op_csr};
assign mem_wr_asid_tlbehi = MEM_valid && csr_we && (csr_num == `CSR_TLBEHI || csr_num == `CSR_ASID);

endmodule