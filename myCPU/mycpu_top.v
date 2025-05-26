`include "constants.vh"

module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,

    //读请求通道
    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,

    //读响应通道
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    //写请求通道
    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,

    //写数据通道
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    //写响应通道
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,

    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

wire reset;

//inst sram interface
wire        inst_sram_req;
wire        inst_sram_wr;
wire [ 1:0] inst_sram_size;
wire [ 3:0] inst_sram_wstrb;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire        inst_sram_addr_ok;
wire        inst_sram_data_ok;
wire [31:0] inst_sram_rdata;

//data sram interface
wire        data_sram_req;
wire        data_sram_wr;
wire [ 1:0] data_sram_size;
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;
wire [31:0] data_sram_rdata;

//ICache interface
wire         inst_rd_req;
wire [ 2:0]  inst_rd_type; //只有3'b100有效 16Bits
wire [31:0]  inst_rd_addr;
wire         inst_rd_rdy;

wire         inst_ret_valid;
wire         inst_ret_last;
wire [31:0]  inst_ret_data;

wire         inst_wr_req;
wire [  2:0] inst_wr_type;
wire [ 31:0] inst_wr_addr;
wire [  3:0] inst_wr_wstrb;
wire [127:0] inst_wr_data;
wire         inst_wr_rdy;

//Dcache interface
wire         data_rd_req;
wire [ 2:0]  data_rd_type; //只有3'b100有效 16Bits
wire [31:0]  data_rd_addr;
wire         data_rd_rdy;

wire         data_ret_valid;
wire         data_ret_last;
wire [31:0]  data_ret_data;

wire         data_wr_req;
wire [  2:0] data_wr_type;
wire [ 31:0] data_wr_addr;
wire [  3:0] data_wr_wstrb;
wire [127:0] data_wr_data;
wire         data_wr_rdy;

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

wire [31:0]  cntvl;
wire [31:0]  cntvh;

wire [`forwrd_data_width  :0]  EX_forward;
wire [`forwrd_data_width  :0]  MEM_forward;
wire [`forwrd_data_width-1:0]  WB_forward;

wire        mem_ex;
wire        wb_ex;
wire [ 5:0] wb_ecode;
wire [ 8:0] wb_esubcode;
wire [31:0] wb_pc;
wire [31:0] wb_vaddr;
wire [31:0] ex_entry;
wire        ertn_flush;
wire        csr_reset;
wire [ 1:0] csr_plv;
wire        has_int;

wire                      csr_re;
wire [`CSR_NUM_WIDTH-1:0] csr_num;
wire [31:0]               csr_rvalue;
wire                      csr_we;
wire [31:0]               csr_wmask;
wire [31:0]               csr_wvalue;

assign reset = ~aresetn;

assign to_IF_valid = aresetn;

IF_stage u_IF_stage(
    .clk               (aclk),
    .reset             (reset),

    .csr_reset         (csr_reset),
    .ex_entry          (ex_entry),

    .inst_sram_req     (inst_sram_req),
    .inst_sram_wr      (inst_sram_wr),
    .inst_sram_size    (inst_sram_size),
    .inst_sram_wstrb   (inst_sram_wstrb),
    .inst_sram_addr    (inst_sram_addr),
    .inst_sram_wdata   (inst_sram_wdata),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_rdata   (inst_sram_rdata),

    .to_IF_valid       (to_IF_valid),
    .ID_allow_in       (ID_allow_in),
    .IF_to_ID_valid    (IF_to_ID_valid),
    .to_ID_data        (to_ID_data),
    .br_data           (br_data)
);

ID_stage u_ID_stage(
    .clk            (aclk),
    .reset          (reset),

    .csr_reset      (csr_reset),
    .has_int        (has_int),

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
    .clk            (aclk),
    .reset          (reset),

    .csr_reset      (csr_reset),
    .mem_ex         (mem_ex),
    .wb_ex          (wb_ex),

    .MEM_allow_in   (MEM_allow_in),
    .to_EX_data     (to_EX_data),
    .to_MEM_data    (to_MEM_data),
    .ID_to_EX_valid (ID_to_EX_valid),
    .EX_to_MEM_valid(EX_to_MEM_valid),
    .EX_allow_in    (EX_allow_in),

    .data_sram_req  (data_sram_req),
    .data_sram_wr   (data_sram_wr),
    .data_sram_size (data_sram_size),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_addr (data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),

    .EX_forward     (EX_forward)
);

MEM_stage u_MEM_stage(
    .clk               (aclk),
    .reset             (reset),
    
    .csr_reset         (csr_reset),
    .mem_ex            (mem_ex),

    .data_sram_data_ok (data_sram_data_ok),
    .data_sram_rdata   (data_sram_rdata),

    .cntvl             (cntvl),
    .cntvh             (cntvh),

    .WB_allow_in       (WB_allow_in),
    .to_MEM_data       (to_MEM_data),
    .to_WB_data        (to_WB_data),
    .EX_to_MEM_valid   (EX_to_MEM_valid),
    .MEM_to_WB_valid   (MEM_to_WB_valid),
    .MEM_allow_in      (MEM_allow_in),

    .MEM_forward       (MEM_forward)
);

WB_stage u_WB_stage(
    .clk            (aclk),
    .reset          (reset),

    .csr_reset      (csr_reset),

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
    .wb_vaddr          (wb_vaddr),
    .wb_pc             (wb_pc),
    .ertn_flush        (ertn_flush),
    .csr_plv           (csr_plv),

    .csr_re            (csr_re),
    .csr_num           (csr_num),
    .csr_rvalue        (csr_rvalue),
    .csr_we            (csr_we),
    .csr_wmask         (csr_wmask),
    .csr_wvalue        (csr_wvalue)
);

CSR_module u_CSR_module(
    .clk                      (aclk),
    .reset                    (reset),

    .csr_re                   (csr_re),
    .csr_num                  (csr_num),
    .csr_rvalue               (csr_rvalue),
    .csr_we                   (csr_we),
    .csr_wmask                (csr_wmask),
    .csr_wvalue               (csr_wvalue),

    .hw_int_in                (8'b0),
    .ipi_int_in               (1'b0),//暂时无输入来源
    .has_int                  (has_int),
    .ex_entry                 (ex_entry),
    .csr_reset                (csr_reset),
    .ertn_flush               (ertn_flush),
    .wb_ex_with_ertn          (wb_ex), //注意转换
    .wb_pc                    (wb_pc),
    .wb_vaddr                 (wb_vaddr),
    .wb_ecode                 (wb_ecode),
    .wb_esubcode              (wb_esubcode),
    .csr_plv                  (csr_plv)
);

StableCounter u_StableCounter(
    .clk    (aclk),
    .reset  (reset),
    .cntvl  (cntvl),
    .cntvh  (cntvh)
);

SRAMtoAXI_Bridge u_SRAMtoAXI_Bridge(
    .clk                (aclk),
    .reset              (reset),

    // ICache接口
    .inst_rd_req    (inst_rd_req    ),    // 读请求
    .inst_rd_type   (inst_rd_type   ),    // 读类型
    .inst_rd_addr   (inst_rd_addr   ),    // 读地址
    .inst_rd_rdy    (inst_rd_rdy    ),    // 读就绪

    .inst_ret_valid (inst_ret_valid ),    // 返回数据有效
    .inst_ret_last  (inst_ret_last  ),    // 返回最后一个数据
    .inst_ret_data  (inst_ret_data  ),    // 返回数据

    .inst_wr_req    (inst_wr_req    ),    // 写请求
    .inst_wr_type   (inst_wr_type   ),    // 写类型
    .inst_wr_addr   (inst_wr_addr   ),    // 写地址
    .inst_wr_wstrb  (inst_wr_wstrb  ),    // 写使能
    .inst_wr_data   (inst_wr_data   ),    // 写数据
    .inst_wr_rdy    (inst_wr_rdy    ),    // 写就绪

    // DCache接口
    .data_rd_req    (data_rd_req    ),    // 读请求
    .data_rd_type   (data_rd_type   ),    // 读类型
    .data_rd_addr   (data_rd_addr   ),    // 读地址
    .data_rd_rdy    (data_rd_rdy    ),    // 读就绪

    .data_ret_valid (data_ret_valid ),    // 返回数据有效
    .data_ret_last  (data_ret_last  ),    // 返回最后一个数据
    .data_ret_data  (data_ret_data  ),    // 返回数据

    .data_wr_req    (data_wr_req    ),    // 写请求
    .data_wr_type   (data_wr_type   ),    // 写类型
    .data_wr_addr   (data_wr_addr   ),    // 写地址
    .data_wr_wstrb  (data_wr_wstrb  ),    // 写使能
    .data_wr_data   (data_wr_data   ),    // 写数据
    .data_wr_rdy    (data_wr_rdy    ),    // 写就绪

    //读请求通道
    .arid               (arid      ),
    .araddr             (araddr    ),
    .arlen              (arlen     ),
    .arsize             (arsize    ),
    .arburst            (arburst   ),
    .arlock             (arlock    ),
    .arcache            (arcache   ),
    .arprot             (arprot    ),
    .arvalid            (arvalid   ),
    .arready            (arready   ),

    //读响应通道
    .rid                (rid       ),
    .rdata              (rdata     ),
    .rresp              (rresp     ),
    .rlast              (rlast     ),
    .rvalid             (rvalid     ),
    .rready             (rready     ),

    //写请求通道
    .awid               (awid      ),
    .awaddr             (awaddr    ),
    .awlen              (awlen     ),
    .awsize             (awsize    ),
    .awburst            (awburst   ),
    .awlock             (awlock    ),
    .awcache            (awcache   ),
    .awprot             (awprot    ),
    .awvalid            (awvalid   ),
    .awready            (awready   ),

    //写数据通道
    .wid                (wid       ),
    .wdata              (wdata     ),
    .wstrb              (wstrb     ),
    .wlast              (wlast     ),
    .wvalid             (wvalid    ),
    .wready             (wready    ),

    //写响应通道
    .bid                (bid       ),
    .bresp              (bresp     ),
    .bvalid             (bvalid    ),
    .bready             (bready    )
);

regfile u_regfile(
    .clk    (aclk     ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

cache ICache (
    // 时钟与复位
    .clk        (aclk                 ),    // 时钟信号
    .resetn     (aresetn              ),    // 低有效复位

    // CPU接口
    .valid      (inst_sram_req        ),    // 请求有效
    .op         (inst_sram_wr         ),    // 读写操作
    .index      (inst_sram_addr[11: 4]),    // addr[11:4]
    .tag        (inst_sram_addr[31:12]),    // addr[31:12]
    .offset     (inst_sram_addr[ 3: 0]),    // addr[3:0]
    .wstrb      (inst_sram_wstrb      ),    // 写使能
    .wdata      (inst_sram_wdata      ),    // 写数据
    .addr_ok    (inst_sram_addr_ok    ),    // 地址握手
    .data_ok    (inst_sram_data_ok    ),    // 数据握手
    .rdata      (inst_sram_rdata      ),    // 读数据

    // AXIS转接桥读请求握手
    .rd_req     (inst_rd_req          ),    // 读请求
    .rd_type    (inst_rd_type         ),    // 读类型
    .rd_addr    (inst_rd_addr         ),    // 读地址
    .rd_rdy     (inst_rd_rdy          ),    // 读就绪

    // AXIS转接桥读数据握手
    .ret_valid  (inst_ret_valid       ),    // 返回数据有效
    .ret_last   (inst_ret_last        ),    // 返回最后一个数据
    .ret_data   (inst_ret_data        ),    // 返回数据

    // AXIS转接桥写请求握手
    .wr_req     (inst_wr_req          ),    // 写请求
    .wr_type    (inst_wr_type         ),    // 写类型
    .wr_addr    (inst_wr_addr         ),    // 写地址
    .wr_wstrb   (inst_wr_wstrb        ),    // 写使能
    .wr_data    (inst_wr_data         ),    // 写数据
    .wr_rdy     (inst_wr_rdy          )     // 写就绪
);

cache DCache (
    // 时钟与复位
    .clk        (aclk                 ),    // 时钟信号
    .resetn     (aresetn              ),    // 低有效复位

    // CPU接口
    .valid      (data_sram_req        ),    // 请求有效
    .op         (data_sram_wr         ),    // 读写操作
    .index      (data_sram_addr[11: 4]),    // addr[11:4]
    .tag        (data_sram_addr[31:12]),    // addr[31:12]
    .offset     (data_sram_addr[ 3: 0]),    // addr[3:0]
    .wstrb      (data_sram_wstrb      ),    // 写使能
    .wdata      (data_sram_wdata      ),    // 写数据
    .addr_ok    (data_sram_addr_ok    ),    // 地址握手
    .data_ok    (data_sram_data_ok    ),    // 数据握手
    .rdata      (data_sram_rdata      ),    // 读数据

    // AXIS转接桥读请求握手
    .rd_req     (data_rd_req          ),    // 读请求
    .rd_type    (data_rd_type         ),    // 读类型
    .rd_addr    (data_rd_addr         ),    // 读地址
    .rd_rdy     (data_rd_rdy          ),    // 读就绪

    // AXIS转接桥读数据握手
    .ret_valid  (data_ret_valid       ),    // 返回数据有效
    .ret_last   (data_ret_last        ),    // 返回最后一个数据
    .ret_data   (data_ret_data        ),    // 返回数据

    // AXIS转接桥写请求握手
    .wr_req     (data_wr_req          ),    // 写请求
    .wr_type    (data_wr_type         ),    // 写类型
    .wr_addr    (data_wr_addr         ),    // 写地址
    .wr_wstrb   (data_wr_wstrb        ),    // 写使能
    .wr_data    (data_wr_data         ),    // 写数据
    .wr_rdy     (data_wr_rdy          )     // 写就绪
);

endmodule