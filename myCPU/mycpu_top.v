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



// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = dest;
assign debug_wb_rf_wdata = final_result;

endmodule




parameter to_ID_data_width = 64;
parameter to_EX_data_width = 

module IF_stage(
    input   wire                        clk,
    input   wire                        reset,

    output  wire                        inst_sram_en,
    output  wire [3:0]                  inst_sram_we,
    output  wire [31:0]                 inst_sram_addr,
    output  wire [31:0]                 inst_sram_wdata,
    input   wire [31:0]                 inst_sram_rdata,

    input   wire                        to_IF_valid,
    input   wire                        ID_allow_in,
    output  wire                        IF_to_ID_valid,
    output  wire [to_ID_data_width-1:0] to_ID_data,

    input   wire [31:0]                 nextpc
)

reg IF_valid;
wire IF_ready_go;
wire IF_allow_in;

reg  [31:0] pc;
wire [31:0] inst;

//控制阻塞信号
assign IF_ready_go = 1'b1;//无阻塞
assign IF_allow_in = ~IF_valid | (IF_ready_go & ID_allow_in);
assign IF_to_ID_valid = IF_valid & IF_ready_go;

always @(posedge clk) begin
    if (reset)
        IF_valid <= 1'b0;
    else if (IF_ready_go)
        IF_valid <= to_IF_valid;
end

//pc信号控制
always @(posedge clk) begin
    if (reset)
        pc <= 32'h1bfffffc;//使重置后的pc为0x1c000000
    else
        pc <=nextpc;
end

//读inst_sram
assign inst_sram_en = to_IF_valid & IF_allow_in;//读nextpc地址，所以判断输入数据是否有效
assign inst_sram_we = {4{1'b0}};
assign inst_sram_addr = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst = inst_sram_rdata;

//传递数据
assign to_ID_data = {pc, inst};//{32, 32}

endmodule

module ID_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire                    
    input   wire                          EX_allow_in,
    input   wire [to_ID_data_width-1:0]   to_ID_data,
    output  wire [to_EX_data_width-1:0]   to_EX_data,
    output  wire [31:0]                   nextpc,
    output  wire                          ID_to_EX_valid,
    output  wire                          ID_allow_in,

)

reg ID_valid;
wire ID_ready_go;

wire [31:0] seq_pc;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] inst;
wire [31:0] pc;

wire [11:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
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
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [31:0] mem_result;
wire [31:0] final_result;

//控制阻塞信号
assign ID_ready_go = 1'b1;//无阻塞
assign ID_allow_in = ~ID_valid | (ID_ready_go & EX_allow_in);
assign ID_to_EX_valid = ID_valid & ID_ready_go;

always @(posedge clk) begin
    if (reset)
        ID_valid <= 1'b0;
    else if (ID_ready_go)
        ID_valid <= IF_to_ID_valid;
end

assign {pc, inst} = to_ID_data;
assign to_EX_data ={pc, //32
                    rj_value, //32
                    rkd_value, //32
                    imm, //32
                    alu_op, //12
                    src1_is_pc, //1
                    src2_is_imm, //1
                    mem_we, //1
                    res_from_mem, //1
                    dest, //32
                    gr_we //1
                    };

assign seq_pc       = pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc;

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];

assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
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

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

endmodule

module EX_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire                          MEM_allow_in,
    input   wire [to_EX_data_width-1:0]   to_EX_data,
    output  wire [to_MEM_data_width-1:0]  to_MEM_data,
    output  wire                          EX_to_MEM_valid,
    output  wire                          EX_allow_in
)

reg EX_valid;
wire EX_ready_go;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire mem_we;
wire res_from_mem;

assign EX_ready_go = 1'b1;//无阻塞
assign EX_allow_in = ~EX_valid | (EX_ready_go & MEM_allow_in);
assign EX_to_MEM_valid = EX_valid & EX_ready_go;

always @(posedge clk) begin
    if (reset)
        EX_valid <= 1'b0;
    else if (EX_ready_go)
        EX_valid <= ID_to_EX_valid;
end

assign {pc,
        rj_value,
        rkd_value,
        imm,
        alu_op,
        src1_is_pc,
        src2_is_imm,
        mem_we,
        res_from_mem,
        dest,
        gr_we} = to_EX_data;

assign to_MEM_data = {alu_result, //32
                      rkd_value, //32
                      mem_we, //1
                      res_from_mem//1
                      dest, //32
                      gr_we //1
                    };

assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
);

endmodule

module MEM_stage(
    input   wire                          clk,
    input   wire                          reset,

    output wire        data_sram_en,
    output wire [3:0]  data_sram_we, 
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    input   wire                          WB_allow_in,
    input   wire [to_MEM_data_width-1:0]  to_MEM_data,
    output  wire [to_WB_data_width-1:0]   to_WB_data,
    output  wire                          MEM_to_WB_valid,
    output  wire                          MEM_allow_in
)

reg MEM_valid;
wire MEM_ready_go;

wire [31:0] alu_result;
wire [31:0] rkd_value;
wire        mem_we;
wire        res_from_mem;

assign MEM_ready_go = 1'b1;//无阻塞
assign MEM_allow_in = ~MEM_valid | (MEM_ready_go & WB_allow_in);
assign MEM_to_WB_valid = MEM_valid & MEM_ready_go;

always @(posedge clk) begin
    if (reset)
        MEM_valid <= 1'b0;
    else if (MEM_ready_go)
        MEM_valid <= EX_to_MEM_valid;
end

assign {alu_result,
        rkd_value,
        mem_we,
        res_from_mem,
        dest,
        gr_we} = to_MEM_data;

assign to_WB_data = {dest, //32
                     final_result, //32
                     gr_we //1
                    };                    

assign data_sram_en    = 1'b1;
assign data_sram_we    = {4{mem_we && valid}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

endmodule

module WB_stage(
    input   wire                          clk,
    input   wire                          reset,

    input   wire [to_WB_data_width-1:0]   to_WB_data,
    input   wire                          MEM_to_WB_valid,
    output  wire                          WB_allow_in,
)

reg WB_valid;
wire WB_ready_go;

wire [31:0] dest;
wire [31:0] final_result;
wire        gr_we;

assgin WB_ready_go = 1'b1;//无阻塞
assign WB_allow_in = ~WB_valid | WB_ready_go;

always @(posedge clk) begin
    if (reset)
        WB_valid <= 1'b0;
    else if (WB_ready_go)
        WB_valid <= MEM_to_WB_valid;
end

assign {dest,
        final_result,
        gr_we} = to_WB_data;

assign rf_we    = gr_we && WB_valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;

endmodule