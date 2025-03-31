`include "constants.h"

module ID_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire                          csr_reset,
    input   wire                          has_int,

    input   wire                          IF_to_ID_valid,             
    input   wire                          EX_allow_in,
    input   wire [`to_ID_data_width-1:0]  to_ID_data,
    output  wire [`to_EX_data_width-1:0]  to_EX_data,
//    output  wire                          to_IF_valid,
    output  wire                          ID_to_EX_valid,
    output  wire                          ID_allow_in,
    output  wire [`br_data_width-1:0]     br_data,

    output  wire [4:0]                    rf_raddr1,
    input   wire [31:0]                   rf_rdata1,
    output  wire [4:0]                    rf_raddr2,
    input   wire [31:0]                   rf_rdata2,

    input   wire [`forwrd_data_width  :0]  EX_forward,
    input   wire [`forwrd_data_width-1:0]  MEM_forward,
    input   wire [`forwrd_data_width-1:0]  WB_forward
);

reg                            ID_valid;
wire                           ID_ready_go;
reg  [`to_ID_data_width-1:0]   to_ID_data_r;

wire [31:0] seq_pc;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] inst;
wire [31:0] pc;
wire        rj_eq_rd;
wire        rj_lt_rd;
wire        rj_ult_rd;
wire        is_b_inst;

wire [18:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_25_24;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] op_14_10;
wire [ 4:0] op_9_5;

wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [ 3:0] op_25_24_d;
wire [31:0] op_19_15_d;
wire [31:0] op_14_10_d;
wire [31:0] op_9_5_d;

wire        inst_rdcntid_w;
wire        inst_rdcntvl_w;
wire        inst_rdcntvh_w;
wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_mod_w;
wire        inst_div_wu;
wire        inst_mod_wu;
wire        inst_break;
wire        inst_syscall;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_slti;
wire        inst_sltui;
wire        inst_addi_w;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_csr;
wire        inst_ertn;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_w;
wire        inst_st_b;
wire        inst_st_h;
wire        inst_st_w;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_lu12i_w;
wire        inst_pcaddu12i;

wire        need_ui5;
wire        need_si12;
wire        need_ui12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;
wire        rdcntvh;
wire        rdcntvl;
wire        rdcntid;

wire        no_rj;
wire        no_rkd;
wire        rj_wait;
wire        rkd_wait;
wire        need_wait;

wire        read_mem_1_byte;
wire        read_mem_2_byte;
wire        read_mem_4_byte;
wire        read_mem_is_signed;
wire        write_mem_1_byte;
wire        write_mem_2_byte;
wire        write_mem_4_byte;
wire        ex_INT;
wire        ex_SYS;
wire        ex_BRK;
wire        ex_ADEF;
wire        ex_INE;
wire        is_ertn;
wire        op_csr;
wire [`CSR_NUM_WIDTH-1:0] csr_num;
wire [31:0] csr_wmask_tmp;
wire        EX_op_csr;
wire        MEM_op_csr;
wire        WB_op_csr;
wire        csr_wait;

wire [ 4:0] EX_dest;
wire [ 4:0] MEM_dest;
wire [ 4:0] WB_dest;
wire [31:0] EX_forward_value;
wire [31:0] MEM_forward_value;
wire [31:0] WB_forward_value;
wire        is_load;

//控制阻塞信号
assign rj_wait  = ~no_rj  && (rf_raddr1 != 5'b0) && (rf_raddr1 == EX_dest || rf_raddr1 == MEM_dest || rf_raddr1 == WB_dest);
assign rkd_wait = ~no_rkd && (rf_raddr2 != 5'b0) && (rf_raddr2 == EX_dest || rf_raddr2 == MEM_dest || rf_raddr2 == WB_dest);
assign csr_wait = EX_op_csr || MEM_op_csr || WB_op_csr;
assign need_wait = is_load || csr_wait; // rj_wait, rkd_wait会有前递信号来保证value的正确，无需阻塞
assign ID_ready_go = ~need_wait || ~ID_valid;
assign ID_allow_in = ~ID_valid | (ID_ready_go & EX_allow_in);
assign ID_to_EX_valid = ID_valid & ID_ready_go;
//assign to_IF_valid = ID_valid;

always @(posedge clk) begin
    if (reset | csr_reset)
        ID_valid <= 1'b0;
    else if (br_taken)
        ID_valid <= 1'b0;
    else if (ID_allow_in)
        ID_valid <= IF_to_ID_valid;

    if (IF_to_ID_valid && ID_allow_in)
        to_ID_data_r <= to_ID_data;
end

assign {pc, inst, ex_ADEF} = to_ID_data_r;
assign to_EX_data ={pc,
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
                    ex_INT,
                    ex_SYS,
                    ex_BRK,
                    ex_ADEF,
                    ex_INE,
                    is_ertn,
                    op_csr,
                    csr_num,
                    csr_wmask_tmp,
                    rj,
                    rdcntvh,
                    rdcntvl,
                    rdcntid
                    };
assign br_data = {br_taken, br_target};

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_25_24  = inst[25:24];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];
assign op_14_10  = inst[14:10];
assign op_9_5    = inst[ 9: 5];

assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];
assign csr_num = rdcntid ? `CSR_TID :
                           inst[23:10];

assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
decoder_5_32 u_dec4(.in(op_14_10 ), .out(op_14_10_d ));
decoder_2_4  u_dec5(.in(op_25_24 ), .out(op_25_24_d ));
decoder_5_32 u_dec6(.in(op_9_5   ), .out(op_9_5_d   ));

assign
    inst_rdcntid_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & ~op_9_5_d[5'h00];
assign 
    inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & op_9_5_d[5'h00];
assign
    inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h19];
assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
assign inst_break  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_csr    = op_31_26_d[6'h01] & op_25_24_d[2'h0];
assign inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0e];
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];
assign inst_pcaddu12i
                   = op_31_26_d[6'h07] & ~inst[25];

assign ex_INE = ~ex_ADEF && 
                ~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor |
                  inst_sll_w | inst_srl_w | inst_sra_w | inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w |
                  inst_mod_w | inst_div_wu | inst_mod_wu | inst_break | inst_syscall | inst_slli_w | inst_srli_w |
                  inst_srai_w | inst_slti | inst_sltui | inst_addi_w | inst_andi | inst_ori | inst_xori | inst_csr |
                  inst_ertn | inst_ld_b | inst_ld_h | inst_ld_w | inst_st_b | inst_st_h | inst_st_w | inst_ld_bu |
                  inst_ld_hu | inst_jirl | inst_b | inst_bl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu |
                  inst_bgeu | inst_lu12i_w | inst_pcaddu12i | inst_rdcntvl_w | inst_rdcntvh_w |inst_rdcntid_w);

assign alu_op[ 0] = inst_add_w | inst_addi_w |
                    inst_ld_b | inst_ld_h | inst_ld_w | inst_st_b | inst_st_h | inst_st_w | inst_ld_bu | inst_ld_hu |
                    inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_mod_w;
assign alu_op[17] = inst_div_wu;
assign alu_op[18] = inst_mod_wu;

assign rdcntvh = inst_rdcntvh_w;
assign rdcntvl = inst_rdcntvl_w;
assign rdcntid = inst_rdcntid_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_b | inst_ld_h  | inst_ld_w  | inst_st_b 
                   | inst_st_h   | inst_st_w | inst_ld_bu | inst_ld_hu | inst_slti 
                   | inst_sltui;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;
assign no_rj      =  inst_lu12i_w | inst_b | inst_bl | inst_pcaddu12i | 
                     inst_syscall | inst_ertn;
assign no_rkd     =  inst_slli_w | inst_srli_w | inst_srai_w | inst_slti | inst_sltui   |
                     inst_addi_w | inst_andi   | inst_ori    | inst_xori | inst_lu12i_w | inst_pcaddu12i |
                     inst_ld_b   | inst_ld_h   | inst_ld_w   | inst_ld_bu| inst_ld_hu   |
                     inst_jirl   | inst_b      | inst_bl     | 
                     inst_syscall| inst_ertn;//TODO：梳理一下例外处理时可以跳过的阻塞
assign ex_INT     =  has_int;
assign ex_SYS     =  inst_syscall;
assign ex_BRK     =  inst_break;
assign is_ertn    =  inst_ertn;
assign op_csr     =  inst_csr | inst_rdcntid_w;
assign csr_wmask_tmp = rj_value;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui12 ? {{20{1'b0}}, i12[11:0]}    :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq  | inst_bne  | inst_blt | inst_bge | inst_bltu | inst_bgeu |
                       inst_st_b | inst_st_h | inst_st_w |
                       inst_csr;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_slti   |
                       inst_sltui  |
                       inst_addi_w |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_ld_b   | inst_ld_h  | inst_ld_w |
                       inst_st_b   | inst_st_h  | inst_st_w |
                       inst_ld_bu  | inst_ld_hu |
                       inst_lu12i_w|
                       inst_pcaddu12i |
                       inst_jirl   |
                       inst_bl     ;

assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_b & ~inst_st_h &~inst_st_w & 
                       ~inst_b & ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu &
                       ~ex_INT & ~ex_SYS & ~ex_BRK & ~ex_ADEF & ~ex_INE & ~is_ertn;
assign dest          = ~gr_we     ? 5'b0 :
                        dst_is_r1 ? 5'd1 :
                        rdcntid   ? rj   : rd; //若无需写寄存器，将dest清为0，方便前递时判断

assign read_mem_1_byte    = inst_ld_b | inst_ld_bu;
assign read_mem_2_byte    = inst_ld_h | inst_ld_hu;
assign read_mem_4_byte    = inst_ld_w;
assign read_mem_is_signed = inst_ld_b | inst_ld_h | inst_ld_w;
assign write_mem_1_byte   = inst_st_b;
assign write_mem_2_byte   = inst_st_h;
assign write_mem_4_byte   = inst_st_w;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;


assign rj_value  = rj_wait ? (rf_raddr1 == EX_dest ? EX_forward_value :
                              rf_raddr1 == MEM_dest ? MEM_forward_value :
      /*rf_raddr1 == WB_dest*/WB_forward_value) : rf_rdata1;
assign rkd_value = rkd_wait ? (rf_raddr2 == EX_dest ? EX_forward_value :
                               rf_raddr2 == MEM_dest ? MEM_forward_value :
       /*rf_raddr2 == WB_dest*/WB_forward_value) : rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign rj_lt_rd = $signed(rj_value) < $signed(rkd_value);
assign rj_ult_rd = $unsigned(rj_value) < $unsigned(rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  &&  rj_lt_rd
                   || inst_bge  && !rj_lt_rd
                   || inst_bltu &&  rj_ult_rd
                   || inst_bgeu && !rj_ult_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                ) && ID_valid && ~need_wait; //br_taken会强制置ID_valid为0，当ID需要阻塞时br_taken也不能为1
assign is_b_inst = inst_b || inst_bl || inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu;
assign br_target = is_b_inst ? (pc + br_offs) : /*inst_jirl*/ (rj_value + jirl_offs);

assign {EX_dest, EX_forward_value, is_load, EX_op_csr} = EX_forward;
assign {MEM_dest, MEM_forward_value, MEM_op_csr} = MEM_forward;
assign {WB_dest, WB_forward_value, WB_op_csr} = WB_forward;

endmodule
