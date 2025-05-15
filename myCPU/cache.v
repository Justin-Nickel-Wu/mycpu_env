module cache(
    input  wire        clk,
    input  wire        reset,

    //from to CPU
    input  wire        valid,
    input  wire        op,
    input  wire [ 7:0] index,  //addr[11:4]
    input  wire [19:0] tag,    //addr[31:12]
    input  wire [ 3:0] offset, //addr[3:0]
    input  wire [ 3:0] wstrb,  //写使能
    input  wire [31:0] wdata,
    output wire        addr_ok,
    output wire        data_ok,
    output wire [31:0] rdata,

    //AXIS转接桥读请求握手
    output wire        rd_req,
    output wire [ 2:0] rd_type, //000:读1字节 001:读2字节 010:读4字节 100:读Cache行
    output wire [31:0] rd_addr,
    input  wire        rd_ready,
    //AXIS转接桥读数据握手
    input  wire        ret_valid,
    input  wire  [1:0] ret_last, //是否是读请求最后一个数据
    input  wire [31:0] ret_data,
    //AXIS转接桥写请求握手
    output wire        wr_req,
    output wire [ 2:0] wr_type, //000:写1字节 001:写2字节 010:写4字节 100:写Cache行
    output wire [31:0] wr_addr,
    output wire [ 3:0] wr_strb, //写使能 写Cache行模式下无意义
    output wire[127:0] wr_data,
    input  wire        wr_rdy
);

localparam main_IDLE    = 5'b00001,
           main_LOOKUP  = 5'b00010,
           main_MISS    = 5'b00100,
           main_REPLACE = 5'b01000,
           main_REFILL  = 5'b10000;
reg [4:0] main_state;

wire main_is_IDLE;
wire main_is_LOOKUP;
wire main_is_MISS;
wire main_is_REPLACE;
wire main_is_REFILL;

wire main_IDLE2LOOKUP;
wire main_LOOKUP2LOOKUP;
wire cache_hit;


reg         req_buffer_op;
reg  [ 7:0] req_buffer_index;
reg  [19:0] req_buffer_tag;
reg  [ 3:0] req_buffer_offset;
reg  [ 3:0] req_buffer_wstrb;
reg  [31:0] req_buffer_wdata;

always @(posedge clk) begin

    if (reset) begin
        main_state <= main_IDLE;
    end
    else case (main_state)
        main_IDLE: begin
            if (valid && main_IDLE2LOOKUP) begin //收到cache请求，并且没有与write buffer中的地址冲突
                main_state <= main_LOOKUP;

                req_buffer_op     <= op;
                req_buffer_index  <= index;
                req_buffer_tag    <= tag;
                req_buffer_offset <= offset;
                req_buffer_wstrb  <= wstrb;
                req_buffer_wdata  <= wdata;
            end
        end 

        main_LOOKUP: begin
            if (valid && main_LOOKUP2LOOKUP) begin //再次收到cache请求···
                main_state <= main_LOOKUP;

                req_buffer_op     <= op;
                req_buffer_index  <= index;
                req_buffer_tag    <= tag;
                req_buffer_offset <= offset;
                req_buffer_wstrb  <= wstrb;
                req_buffer_wdata  <= wdata;
            end
            else if (!cache_hit) begin
                
            end
            else begin
                main_state <= main_IDLE;
            end
        end

        main_MISS: begin

        end

        main_REPLACE: begin

        end

        main_REFILL: begin

        end
    endcase
end

assign main_is_IDLE    = main_state[0];
assign main_is_LOOKUP  = main_state[1];
assign main_is_MISS    = main_state[2];
assign main_is_REPLACE = main_state[3];
assign main_is_REFILL  = main_state[4];

assign main_IDLE2LOOKUP = 1'b0; //TODO
assign main_LOOKUP2LOOKUP = 1'b0; //TODO

assign addr_ok = (main_is_IDLE && main_IDLE2LOOKUP) || (main_is_LOOKUP && main_LOOKUP2LOOKUP);

endmodule