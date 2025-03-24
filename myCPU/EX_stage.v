`include "constants.h"

module EX_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire                          csr_reset,
    input   wire                          mem_ex,
    input   wire                          wb_ex,

    input   wire                          MEM_allow_in,
    input   wire [`to_EX_data_width-1:0]   to_EX_data,
    output  wire [`to_MEM_data_width-1:0]  to_MEM_data,
    input   wire                          ID_to_EX_valid,
    output  wire                          EX_to_MEM_valid,
    output  wire                          EX_allow_in,

    output  wire                          data_sram_en,
    output  wire [3:0]                    data_sram_we,
    output  wire [31:0]                   data_sram_addr,
    output  wire [31:0]                   data_sram_wdata,

    output  wire [`forwrd_data_width:0]   EX_forward
);

reg                          EX_valid;
wire                         EX_ready_go;
reg  [`to_EX_data_width-1:0] to_EX_data_r;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [31:0] pc;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [18:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire [4:0]  dest;
wire        gr_we;
wire        ex_SYS;
wire        ex_BRK;
wire        ex_ADEF;
wire        ex_ADEM;
wire        is_ertn;

wire        read_mem_1_byte;
wire        read_mem_2_byte;
wire        read_mem_4_byte;
wire        read_mem_is_signed;
wire        write_mem_1_byte;
wire        write_mem_2_byte;
wire        write_mem_4_byte;
wire [1:0]  mem_addr_low2;
wire        mem_rw_2_byte;
wire        mem_rw_4_byte;

wire [4:0] EX_dest;
wire       is_load;
wire       alu_wait;

wire op_csr;
wire EX_op_csr;
wire [`CSR_NUM_WIDTH-1:0] csr_num;
wire [31:0] csr_wmask_tmp;
wire [4:0] rj;

assign EX_ready_go = ~EX_valid || ~alu_wait;
assign EX_allow_in = ~EX_valid | (EX_ready_go & MEM_allow_in);
assign EX_to_MEM_valid = EX_valid & EX_ready_go;

always @(posedge clk) begin
    if (reset | csr_reset)
        EX_valid <= 1'b0;
    else if (EX_allow_in)
        EX_valid <= ID_to_EX_valid;

    if (ID_to_EX_valid && EX_allow_in)
            to_EX_data_r <= to_EX_data;
end

assign {pc,
        rj_value,
        rkd_value,
        imm,
        alu_op,
        src1_is_pc,
        src2_is_imm,
        read_mem_1_byte,
        read_mem_2_byte,
        read_mem_4_byte,
        read_mem_is_signed,
        write_mem_1_byte,
        write_mem_2_byte,
        write_mem_4_byte,
        dest,
        gr_we,
        ex_SYS,
        ex_BRK,
        ex_ADEF,
        is_ertn,
        op_csr,
        csr_num,
        csr_wmask_tmp,
        rj} = to_EX_data_r;

assign to_MEM_data = {pc,
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
                      is_ertn,
                      op_csr,
                      csr_num,
                      csr_wmask_tmp,
                      rj
                    };

assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign mem_addr_low2 = alu_result[1:0];

assign data_sram_we = write_mem_1_byte ? (mem_addr_low2 == 2'b00 ? 4'b0001 :
                                          mem_addr_low2 == 2'b01 ? 4'b0010 :
                                          mem_addr_low2 == 2'b10 ? 4'b0100 : 4'b1000) :
                      write_mem_2_byte ? (mem_addr_low2 == 2'b00 ? 4'b0011 : 4'b1100) :
                      write_mem_4_byte ? 4'b1111 : 4'b0000;
assign data_sram_wdata = write_mem_1_byte ? {4{rkd_value[ 7: 0]}} :
                         write_mem_2_byte ? {2{rkd_value[15: 0]}} :
                    /* write_mem_4_byte */  rkd_value;
assign data_sram_en    = EX_valid && ~mem_ex && ~wb_ex && ~ex_ADEM;
assign data_sram_addr  = {alu_result[31:2], 2'b00};

//判断读写内存地址是否对齐
assign mem_rw_2_byte = read_mem_2_byte || write_mem_2_byte;
assign mem_rw_4_byte = read_mem_4_byte || write_mem_4_byte;
assign ex_ADEM = (mem_rw_2_byte && mem_addr_low2[0] != 1'b0) //2'b00 and 2'b10 is ok
              || (mem_rw_4_byte && mem_addr_low2 != 2'b00); //only 2'b00 is ok
//assign EX_dest = dest & {5{EX_valid}} & {5{~res_from_mem}};  //如果为读内存指令，此处前递无意义，所以将EX_dest清为0
//错误写法：如果是一条load指令，他处于EX阶段时仍然需要返回写寄存器号信息来让ID阶段的指令阻塞。若直接清EX_dest为0，则失去了这个信息
assign EX_dest = dest & {5{EX_valid}};
assign is_load = EX_valid & (read_mem_1_byte | read_mem_2_byte | read_mem_4_byte);
assign EX_op_csr = op_csr && EX_valid;
assign EX_forward = {EX_dest, alu_result, is_load, EX_op_csr};

/*
//输出写内存信息
always @(posedge clk) begin
    if (data_sram_we == 4'b1111)
        $display("WRITE MEM, pc: %8h, addr: %8h, data: %8h",pc, alu_result, rkd_value);
end
*/

alu u_alu(
    .clk        (clk       ),
    .reset      (reset     ),
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result),
    .alu_wait   (alu_wait  )
);

endmodule