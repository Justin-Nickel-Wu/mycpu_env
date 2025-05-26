module SRAMtoAXI_Bridge(
    input  wire        clk,
    input  wire        reset,
    //from to ICache
    input  wire         inst_rd_req,
    input  wire [ 2:0]  inst_rd_type, //只有3'b100有效 16Bits
    input  wire [31:0]  inst_rd_addr,
    output wire         inst_rd_rdy,

    output wire         inst_ret_valid,
    output wire         inst_ret_last,
    output wire [31:0]  inst_ret_data,

    input  wire         inst_wr_req,
    input  wire [  2:0] inst_wr_type,
    input  wire [ 31:0] inst_wr_addr,
    input  wire [  3:0] inst_wr_wstrb,
    input  wire [127:0] inst_wr_data,
    output wire         inst_wr_rdy,

    //from to DCache
    input  wire         data_rd_req,
    input  wire [ 2:0]  data_rd_type, //只有3'b100有效 16Bits
    input  wire [31:0]  data_rd_addr,
    output wire         data_rd_rdy,

    output wire         data_ret_valid,
    output wire         data_ret_last,
    output wire [31:0]  data_ret_data,

    input  wire         data_wr_req,
    input  wire [  2:0] data_wr_type,
    input  wire [ 31:0] data_wr_addr,
    input  wire [  3:0] data_wr_wstrb,
    input  wire [127:0] data_wr_data,
    output wire         data_wr_rdy,

    //AXI
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
    output wire        bready
);
//
reg          do_req;
reg          do_req_id;//请求ID号，data:1 inst:0
reg          do_wr;
reg  [  3:0] do_wstrb;
reg  [ 31:0] do_addr;
reg  [127:0] do_wdata;
wire         data_back;

wire        inst_req;
wire        data_req;
wire [31:0] inst_addr;
wire [31:0] data_addr;
wire        inst_is_rdy;
wire        data_is_rdy;

//AXI部分
reg addr_rcv; //是否完成读写地址握手
reg wdata_rcv;//是否完成写数据握手

assign inst_req = inst_rd_req || inst_wr_req;
assign data_req = data_rd_req || data_wr_req;

assign inst_addr = {31{inst_rd_req}} & inst_rd_addr |
                   {31{inst_wr_req}} & inst_wr_addr;
assign data_addr = {31{data_rd_req}} & data_rd_addr |
                   {31{data_wr_req}} & data_wr_addr;
    //同一cache的rd_req与wr_req不会同时为1
assign inst_rd_rdy = !do_req && !data_req;
assign data_rd_rdy = !do_req;

assign inst_wr_rdy = 1'b0; //ICache没有写操作
assign data_wr_rdy = !do_req; //空闲时置起

assign inst_is_rdy = inst_rd_rdy || inst_wr_rdy;
assign data_is_rdy = data_rd_rdy || data_wr_rdy;

assign inst_ret_data  = rdata;
assign data_ret_data  = rdata;
assign inst_ret_last  = rlast;
assign data_ret_last  = rlast;
assign inst_ret_valid = rvalid && !do_req_id;
assign data_ret_valid = rvalid &&  do_req_id;

assign data_back = addr_rcv && ((rvalid && rready && rlast) || (bvalid && bready));

always @(posedge clk) begin
    do_req    <= reset                             ? 1'b0 :
                 !do_req && (inst_req || data_req) ? 1'b1 : //一定能握手完成，更新一次即可
                 data_back                         ? 1'b0 : do_req;

    do_req_id <= reset   ? 1'b0     :
                 !do_req ? data_req : do_req_id;  //只在do_req未置起时更新，因为收到req时，do_req下一拍才能置起
    
    do_wr     <= data_req && data_is_rdy ? data_wr_req :
                 inst_req && inst_is_rdy ? inst_wr_req : do_wr;

    do_wstrb  <= data_req && data_is_rdy ? data_wr_wstrb :
                 inst_req && inst_is_rdy ? inst_wr_wstrb : do_wstrb;

    do_addr   <= data_req && data_is_rdy ? data_addr :
                 inst_req && inst_is_rdy ? inst_addr : do_addr;

    do_wdata  <= data_req && data_is_rdy ? data_wr_data : do_wdata; 
    // do_wdata  <= data_req && data_is_rdy ? data_wr_data :
    //              inst_req && inst_is_rdy ? inst_wr_data : do_wdata; 
end

reg  [1:0] wdata_num; //写数据传输次数
wire [1:0] wdata_num_add_one;

assign wdata_num_add_one[0] = ~wdata_num[0];
assign wdata_num_add_one[1] = wdata_num[0] ^ wdata_num[1];

//写数据传输次数计数
always @(posedge clk) begin
    if (data_req && data_is_rdy) begin
        wdata_num <= 2'b00;
    end else
    if (wvalid && wready) begin
        wdata_num <= wdata_num_add_one;
    end
end

always @(posedge clk) begin
    addr_rcv  <= reset              ? 1'b0 :
                 arvalid && arready ? 1'b1 :
                 awvalid && awready ? 1'b1 :
                 data_back          ? 1'b0 : addr_rcv;
    wdata_rcv <= reset              ? 1'b0 :
                 wvalid && wready   ? 1'b1 : 
                 data_back          ? 1'b0 : wdata_rcv;
end

//读请求 ar
assign arid    = {3'b0, do_req_id};
assign araddr  = {do_addr[31:2], 2'b00};
assign arlen   = 8'b00000011; //一次传输4拍
assign arsize  = 3'b010; //每拍传输4Bits
assign arburst = 2'b01; //地址递增模式
assign arlock  = 2'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;
assign arvalid = do_req && !do_wr && !addr_rcv;

//读响应 r
assign rready  = 1'b1; //时刻准备接收数据。

//写请求 aw
assign awid    = {3'b0, do_req_id};
assign awaddr  = {do_addr[31:2], 2'b00};
assign awlen   = 8'b00000011; //一次传输4拍
assign awsize  = 3'b010; //每拍传输4Bits
assign awburst = 2'b01; //地址递增模式
assign awlock  = 2'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;
assign awvalid = do_req && do_wr && !addr_rcv;


//写数据 w
assign wid     = {3'b0, do_req_id};
assign wdata   = do_wdata[wdata_num * 32 +: 32];
assign wstrb   = do_wstrb;
assign wlast   = wdata_num == 2'b11;;
assign wvalid  = do_req && do_wr && !wdata_rcv;
    //TODO:是否可以改造为收到req即发出请求，而不是缓存后再发出？上述同理

//写响应 b
assign bready  = 1'b1; //时刻准备接收数据。

endmodule