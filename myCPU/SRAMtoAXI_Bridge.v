module SRAMtoAXI_Bridge(
    input  wire        clk,
    input  wire        reset,
    //Inst SRAM 接口
    input  wire        inst_req,
    input  wire        inst_wr,
    input  wire [ 1:0] inst_size,
    input  wire [ 3:0] inst_wstrb,
    input  wire [31:0] inst_addr,
    input  wire [31:0] inst_wdata,
    output wire        inst_addr_ok,
    output wire        inst_data_ok,
    output wire [31:0] inst_rdata,

    //Data SRAM 接口
    input  wire        data_req,
    input  wire        data_wr,
    input  wire [ 1:0] data_size,
    input  wire [ 3:0] data_wstrb,
    input  wire [31:0] data_addr,
    input  wire [31:0] data_wdata,
    output wire        data_addr_ok,
    output wire        data_data_ok,
    output wire [31:0] data_rdata,

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
//类SRAM部分
reg  do_req;
reg  do_req_id;//请求ID号，data:1 inst:0
reg  do_wr;
reg  [ 3:0] do_wstrb;
reg  [31:0] do_addr;
reg  [31:0] do_wdata;
wire data_back;

assign inst_addr_ok = !do_req && !data_req;//如果do_req为0且收到请求，一定能立即完成sram_addr的握手
assign data_addr_ok = !do_req; //优先响应data的请求，注意结合下文逻辑

always @(posedge clk) begin
    do_req    <= reset                             ? 1'b0 :
                 !do_req && (inst_req || data_req) ? 1'b1 : //一定能握手完成，更新一次即可
                 data_back                         ? 1'b0 : do_req;
    do_req_id <= reset   ? 1'b0     :
                 !do_req ? data_req : do_req_id;  //只在do_req未置起时更新，因为收到req时，do_req下一拍才能置起
    
    do_wr     <= data_req && data_addr_ok ? data_wr :
                 inst_req && inst_addr_ok ? inst_wr : do_wr;

    do_wstrb  <= data_req && data_addr_ok ? data_wstrb :
                 inst_req && inst_addr_ok ? inst_wstrb : do_wstrb;
    do_addr   <= data_req && data_addr_ok ? data_addr :
                 inst_req && inst_addr_ok ? inst_addr : do_addr;
    do_wdata  <= data_req && data_addr_ok ? data_wdata :
                 inst_req && inst_addr_ok ? inst_wdata : do_wdata; 
end

assign inst_data_ok = do_req && !do_req_id && data_back;
assign data_data_ok = do_req &&  do_req_id && data_back;
assign inst_rdata = rdata;
assign data_rdata = rdata;

//AXI部分
reg addr_rcv; //是否完成读写地址握手
reg wdata_rcv;//是否完成写数据握手

assign data_back = addr_rcv && ((rvalid && rready) || (bvalid && bready));

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
assign arlen   = 8'b0;
assign arsize  = 3'b010;
assign arburst = 2'b01;
assign arlock  = 2'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;
assign arvalid = do_req && !do_wr && !addr_rcv;

//读响应 r
assign rready  = 1'b1; //时刻准备接收数据。

//写请求 aw
assign awid    = {3'b0, do_req_id};
assign awaddr  = {do_addr[31:2], 2'b00};
assign awlen   = 8'b0;
assign awsize  = 3'b010;
assign awburst = 2'b01;
assign awlock  = 2'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;
assign awvalid = do_req && do_wr && !addr_rcv;

//写数据 w
assign wid     = {3'b0, do_req_id};
assign wdata   = do_wdata;
assign wstrb   = do_wstrb;
assign wlast   = 1'b1;
assign wvalid  = do_req && do_wr && !wdata_rcv;

//写响应 b
assign bready  = 1'b1; //时刻准备接收数据。

endmodule