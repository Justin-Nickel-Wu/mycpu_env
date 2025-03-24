`include "constants.h"

module MEM_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire                          csr_reset,
    output  wire                          mem_ex,

    input   wire [31:0]                   data_sram_rdata,

    input   wire                          WB_allow_in,
    input   wire [`to_MEM_data_width-1:0] to_MEM_data,
    output  wire [`to_WB_data_width-1 :0] to_WB_data,
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
wire [4:0]  dest;
wire        gr_we;
wire        ex_SYS;
wire        ex_BRK;
wire        ex_ADEF;
wire        ex_ADEM;
wire        ex_INE;
wire        is_ertn;

wire        res_from_mem;
wire        read_mem_1_byte;
wire        read_mem_2_byte;
wire        read_mem_4_byte;
wire        read_mem_is_signed;
wire [ 1:0] read_mem_addr;
wire [ 7:0] mem_data_1_byte;
wire [15:0] mem_data_2_byte;
wire [31:0] final_mem_data_1_byte;
wire [31:0] final_mem_data_2_byte;
wire [31:0] final_mem_data;

wire [31:0] mem_data_4_byte;
wire [31:0] final_result;

wire [4:0]  MEM_dest;

wire op_csr;
wire MEM_op_csr;
wire [`CSR_NUM_WIDTH-1:0] csr_num;
wire [31:0] csr_wmask_tmp;
wire [4:0] rj;

assign MEM_ready_go = 1'b1;//无阻塞
assign MEM_allow_in = ~MEM_valid | (MEM_ready_go & WB_allow_in);
assign MEM_to_WB_valid = MEM_valid & MEM_ready_go;
assign mem_ex = MEM_valid && (ex_SYS || ex_BRK || ex_ADEF || is_ertn);

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
        dest,
        gr_we,
        ex_SYS,
        ex_BRK,
        ex_ADEF,
        ex_ADEM,
        ex_INE,
        is_ertn,
        op_csr,
        csr_num,
        csr_wmask_tmp,
        rj} = to_MEM_data_r;

assign to_WB_data = {pc,//32
                     dest, //5
                     final_result, //32
                     gr_we, //1
                     ex_SYS,
                     ex_BRK,
                     ex_ADEF,
                     ex_ADEM,
                     ex_INE,
                     is_ertn,
                     op_csr,
                     csr_num,
                     csr_wmask_tmp,
                     rj
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

assign final_result = res_from_mem ? final_mem_data : alu_result;

assign MEM_dest = dest & {5{MEM_valid}};
assign MEM_op_csr = op_csr && MEM_valid;
assign MEM_forward = {MEM_dest, final_result, MEM_op_csr};


endmodule