module cache(
    input  wire        clk,
    input  wire        resetn,

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
    input  wire        rd_rdy,
    //AXIS转接桥读数据握手
    input  wire        ret_valid,
    input  wire        ret_last, //是否是读请求最后一个数据
    input  wire [31:0] ret_data,
    //AXIS转接桥写请求握手
    output reg         wr_req,
    output wire [ 2:0] wr_type, //000:写1字节 001:写2字节 010:写4字节 100:写Cache行
    output wire [31:0] wr_addr,
    output wire [ 3:0] wr_wstrb, //写使能 写Cache行模式下无意义
    output wire[127:0] wr_data,
    input  wire        wr_rdy
);

wire reset;

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

localparam write_buffer_IDLE  = 2'b01,
           write_buffer_WRITE = 2'b10;
reg [1:0] write_buffer_state;

wire write_buffer_is_IDLE;
wire write_buffer_is_WRITE;

wire         cache_hit;
wire [  1:0] way_hit;
wire [127:0] way_data[1:0];
wire [ 31:0] way_load_word[1:0];
wire [ 31:0] load_res;

wire [ 1:0] random_val;
wire [ 1:0] rand_replace_way;
wire [ 1:0] invalid_way;
wire        has_invalid;
wire [ 1:0] way_d;
wire        replace_d;
wire        replace_v;
wire [ 1:0] replace_way;
wire [19:0] replace_tag;
wire [127:0] replace_data;

reg         req_buffer_op;
reg  [ 7:0] req_buffer_index;
reg  [19:0] req_buffer_tag;
reg  [ 3:0] req_buffer_offset;
reg  [ 3:0] req_buffer_wstrb;
reg  [31:0] req_buffer_wdata;
reg  [ 1:0] miss_buffer_replace_way;
reg  [ 1:0] miss_buffer_ret_num;
wire [ 1:0] ret_num_add_one;
wire [31:0] write_in;
wire [31:0] refill_data;

reg  [ 7:0] write_buffer_index;
reg  [ 3:0] write_buffer_wstrb;
reg  [31:0] write_buffer_wdata;
reg  [ 3:0] write_buffer_offset;
reg  [ 1:0] write_buffer_way;

wire [ 1:0] way_bank_wr_en;
wire [ 7:0] way_bank_addra    [1:0][3:0];
wire [31:0] way_bank_dina     [1:0][3:0];
wire [31:0] way_bank_douta    [1:0][3:0];
wire        way_bank_ena      [1:0][3:0];
wire [ 3:0] way_bank_wea      [1:0][3:0];
wire        way_bank_wr_match [1:0][3:0];

wire [ 7:0] way_tagv_addra [1:0];
wire [20:0] way_tagv_dina  [1:0];//20:1 tag 0 v
wire [20:0] way_tagv_douta [1:0];
wire        way_tagv_ena   [1:0];
wire        way_tagv_wea   [1:0];

reg  [ 1:0] way_d_reg [255:0];

genvar  i,j;

assign reset = ~resetn;

always @(posedge clk) begin
    if (reset) begin
        main_state <= main_IDLE;

        req_buffer_op     <= 1'b0;
        req_buffer_index  <= 8'b0;
        req_buffer_offset <= 4'b0;
        req_buffer_wstrb  <= 4'b0;
        req_buffer_wdata  <= 32'b0;

        wr_req <= 1'b0;
    end
    else case (main_state)
        main_IDLE: begin
            if (valid && main_IDLE2LOOKUP) begin //收到cache请求，并且没有与write buffer中的地址冲突
                main_state <= main_LOOKUP;

                req_buffer_op     <= op;
                req_buffer_index  <= index;
                req_buffer_offset <= offset;
                req_buffer_wstrb  <= wstrb;
                req_buffer_wdata  <= wdata;
                req_buffer_tag    <= tag;
            end
        end 

        main_LOOKUP: begin
            if (valid && main_LOOKUP2LOOKUP) begin //再次收到cache请求···
                main_state <= main_LOOKUP;

                req_buffer_op     <= op;
                req_buffer_index  <= index;
                req_buffer_offset <= offset;
                req_buffer_wstrb  <= wstrb;
                req_buffer_wdata  <= wdata;
                req_buffer_tag    <= tag;
            end
            else if (!cache_hit) begin
                if (replace_d && replace_v) begin
                    main_state <= main_MISS;
                end else begin
                    main_state <= main_REPLACE;
                end
                miss_buffer_replace_way <= replace_way;
            end
            else begin
                main_state <= main_IDLE;
            end
        end

        main_MISS: begin
            if (wr_rdy) begin
                main_state <= main_REPLACE;
                wr_req <= 1'b1;
            end
        end
            //MISS阶段发出wr_req请求的只有Dcache，是一定会被接受的
        main_REPLACE: begin
            if (rd_rdy) begin
                main_state <= main_REFILL;
                miss_buffer_ret_num <= 2'b0;
            end
            wr_req <= 1'b0;
        end
            //REPLACE发出的rd_req不一定会被马上处理（ICache与Dcache同时发出请求），收到rd_rdy后进入下一阶段。
        main_REFILL: begin
            if (ret_valid && ret_last) begin //如果没有置高，则跳过refill阶段。对应store且cache hit
                main_state <= main_IDLE;
            end else begin
                if (ret_valid) begin
                    miss_buffer_ret_num <= ret_num_add_one;
                end
            end
        end
    endcase
end

always @(posedge clk) begin
    if (reset) begin
        write_buffer_state  <= write_buffer_IDLE;

        write_buffer_index  <= 8'b0;
        write_buffer_wstrb  <= 4'b0;
        write_buffer_wdata  <= 32'b0;
        write_buffer_offset <= 4'b0;
        write_buffer_way    <= 2'b0;
    end
    else case (write_buffer_state)
        write_buffer_IDLE: begin
            if (main_is_LOOKUP && cache_hit && req_buffer_op) begin
                write_buffer_state <= write_buffer_WRITE;

                write_buffer_index  <= req_buffer_index;
                write_buffer_wstrb  <= req_buffer_wstrb;
                write_buffer_wdata  <= req_buffer_wdata;
                write_buffer_offset <= req_buffer_offset;
                write_buffer_way    <= way_hit;
            end
        end

        write_buffer_WRITE: begin
            if (main_is_LOOKUP && cache_hit && req_buffer_op) begin
                write_buffer_state <= write_buffer_WRITE;

                write_buffer_index  <= req_buffer_index;
                write_buffer_wstrb  <= req_buffer_wstrb;
                write_buffer_wdata  <= req_buffer_wdata;
                write_buffer_offset <= req_buffer_offset;
                write_buffer_way    <= way_hit;
            end else begin
                write_buffer_state <= write_buffer_IDLE;
            end
        end
    endcase
end

assign main_is_IDLE    = main_state[0];
assign main_is_LOOKUP  = main_state[1];
assign main_is_MISS    = main_state[2];
assign main_is_REPLACE = main_state[3];
assign main_is_REFILL  = main_state[4];

assign write_buffer_is_IDLE  = write_buffer_state[0];
assign write_buffer_is_WRITE = write_buffer_state[1];

/*===============================IDLE===============================*/
assign main_IDLE2LOOKUP = !(write_buffer_is_WRITE && write_buffer_offset[3:2] == offset[3:2]);
    //选中的bank块不能与write_buffer中的冲突。若块不同可以同时操作。

/*===============================LOOKUP===============================*/
assign main_LOOKUP2LOOKUP = !(write_buffer_is_WRITE && write_buffer_offset[3:2] == offset[3:2]) && //同上
                            !(req_buffer_op && !op && req_buffer_offset[3:2] == offset[3:2]) && //此时req_buffer需要送入write_buffer,本质同上
                            cache_hit; //当前req_buffer要hit才能送走，大前提。

assign addr_ok = (main_is_IDLE && main_IDLE2LOOKUP) || (main_is_LOOKUP && main_LOOKUP2LOOKUP);

//生成cache hit逻辑信号
generate for (i=0; i<2; i=i+1) begin: gen_way_hit
    assign way_hit[i] = way_tagv_douta[i][0] && (req_buffer_tag == way_tagv_douta[i][20:1]);
        //v位为1，且tag匹配
end endgenerate
assign cache_hit = |way_hit;

//生成返回数据信号
generate for (i=0; i<2; i=i+1) begin: gen_way_data
    assign way_data[i] = {way_bank_douta[i][3], way_bank_douta[i][2], way_bank_douta[i][1], way_bank_douta[i][0]}; //4个bank的输出拼接成128位数据
    assign way_load_word[i] = way_data[i][req_buffer_offset[3:2] * 32 +: 32];
end endgenerate

assign load_res = ({32{way_hit[0]}} & way_load_word[0]) |
                  ({32{way_hit[1]}} & way_load_word[1]);
                
//生成替换路信号
lsfr u_lsfr(.clk(clk), .reset(reset), .random_val(random_val));
decoder_2_4 gen_rand_replace_way(.in({1'b0, random_val[0]}), .out(rand_replace_way)); //01 or 10
one_valid_n #(2) gen_invalid_way(
    .in     (~{way_tagv_douta[1][0], way_tagv_douta[0][0]}),
    .out    (invalid_way),
    .nozero (has_invalid)
);
assign way_d = way_d_reg[req_buffer_index] | 
             {2{(write_buffer_is_WRITE && write_buffer_index == req_buffer_index)}} & write_buffer_way;
    //way_d可能会会被当前写状态机的写事件标记脏
assign replace_way = has_invalid ? invalid_way : rand_replace_way;
    //如果有无效行，使用无效行，否则使用随机行
assign replace_d = |(replace_way & way_d);
assign replace_v = |(replace_way & {way_tagv_douta[1][0], way_tagv_douta[0][0]});

/*================================MISS================================*/
//生成AXI写请求信号
assign replace_tag  = {20{miss_buffer_replace_way[0]}} & way_tagv_douta[0][20:1] |
                      {20{miss_buffer_replace_way[1]}} & way_tagv_douta[1][20:1];
assign replace_data = {128{miss_buffer_replace_way[0]}} & way_data[0] |
                      {128{miss_buffer_replace_way[1]}} & way_data[1];
assign wr_type = 3'b100; //写cache行
assign wr_addr = {replace_tag, req_buffer_index, 4'b0000};
assign wr_wstrb = 4'b1111;
assign wr_data = replace_data;

/*================================REPLACE================================*/
assign rd_req  = main_is_REPLACE;
assign rd_type = 3'b100; //读cache行
assign rd_addr = {req_buffer_tag, req_buffer_index, 4'b0000};

/*================================REFILL================================*/
assign rdata = {32{main_is_LOOKUP}} & load_res |
               {32{main_is_REFILL}} & ret_data;

assign data_ok = (main_is_LOOKUP && (cache_hit || req_buffer_op)) || //包括了read hit 与 write hit
                 (main_is_REFILL && !req_buffer_op && ret_valid && miss_buffer_ret_num == req_buffer_offset[3:2]);
    //对于写操作，总是在LOOKUP立刻返回data_ok，非写操作如果cache miss将在refill阶段收到所请求的字时返回data_ok
    //这样子可以避免阻塞CPU内核
//返回数据的组计数
assign ret_num_add_one[0] = ~miss_buffer_ret_num[0];
assign ret_num_add_one[1] = miss_buffer_ret_num[0] ^ miss_buffer_ret_num[1];

assign write_in = {(req_buffer_wstrb[3] ? req_buffer_wdata[31:24] : ret_data[31:24]),
                   (req_buffer_wstrb[2] ? req_buffer_wdata[23:16] : ret_data[23:16]),
                   (req_buffer_wstrb[1] ? req_buffer_wdata[15: 8] : ret_data[15: 8]),
                   (req_buffer_wstrb[0] ? req_buffer_wdata[ 7: 0] : ret_data[ 7: 0])};
    //store指令会写数据
assign refill_data = (req_buffer_op && (req_buffer_offset[3:2] == miss_buffer_ret_num)) ? write_in : ret_data;
    //最终fill in bank的数据
assign way_bank_wr_en = miss_buffer_replace_way & {2{ret_valid}};
    //控制选中way的写使能

//BANK读写逻辑信号
generate for (i=0; i<2; i=i+1) begin: gen_data_way
    for (j=0; j<4; j=j+1) begin: gen_data_bank
        assign way_bank_wr_match[i][j] = write_buffer_is_WRITE && (write_buffer_way[i] && write_buffer_offset[3:2] == j[1:0]);
            //写状态机处于写状态，并且匹配上了对应word
        assign way_bank_addra[i][j] = way_bank_wr_match[i][j] ? write_buffer_index : ({8{ addr_ok}} & index              |
                                                                                      {8{!addr_ok}} & req_buffer_index);
            //write hit只会写一个word，即wr_match一行至多只有1个高电平，此时写write_buffer_index，需要与wea配合使用
            //其余时刻为lookup服务
        assign way_bank_wea[i][j] = {4{way_bank_wr_match[i][j]}} & write_buffer_wstrb | //store写入word
                                    {4{main_is_REFILL && (way_bank_wr_en[i] && miss_buffer_ret_num == j[1:0])}};//refill写入行
        assign way_bank_dina[i][j] = {32{write_buffer_is_WRITE}} & write_buffer_wdata |
                                     {32{main_is_REFILL}}        & refill_data;
            //当write hit与refill存在潜在竞争，但实际不会发生：
            //write_buffer在lookup启动，两拍一定能完成写入
            //而相近的refill只能是下一次（只有idle与lookup能接受cache请求），
            //最快也需要经历lookup replace refill，第三拍才会进入refill状态
        assign way_bank_ena[i][j] = 1'b1;
            //始终开启
    end
end endgenerate

//TAGV读写逻辑信号
generate for (i=0; i<2; i=i+1) begin: gen_tagv_way
    assign way_tagv_ena[i] = 1'b1;//始终开启
    assign way_tagv_addra[i] = {8{ addr_ok}} & index |
                               {8{!addr_ok}} & req_buffer_index;
                               //addr_ok在收到cache同拍置1，此时index还未置入buffer，此后addr_ok置低，使用buffer即可
    assign way_tagv_wea[i] = miss_buffer_replace_way[i] && main_is_REFILL && ((ret_valid && ret_last));
        //当所有数据返回后写tagv
    assign way_tagv_dina[i] = {req_buffer_tag, 1'b1};
end endgenerate

//way_d_reg维护
always @(posedge clk) begin
    if (main_is_REFILL && ret_valid && ret_last) begin
        way_d_reg[req_buffer_index][0] <= miss_buffer_replace_way[0] ? req_buffer_op : way_d_reg[req_buffer_index][0];
        way_d_reg[req_buffer_index][1] <= miss_buffer_replace_way[1] ? req_buffer_op : way_d_reg[req_buffer_index][1];
    end 
    else if (write_buffer_is_WRITE) begin
        way_d_reg[write_buffer_index] <= way_d_reg[write_buffer_index] | write_buffer_way;
    end
end

//生成BANK
generate for (i=0; i<2; i=i+1) begin: data_ram_way
    for (j=0; j<4; j=j+1) begin: data_ram_bank
        data_bank_sram u(
            .clka  (clk),
            .reset (reset),
            .ena   (way_bank_ena[i][j]),
            .wea   (way_bank_wea[i][j]),
            .addra (way_bank_addra[i][j]),
            .dina  (way_bank_dina[i][j]),
            .douta (way_bank_douta[i][j])
        );
    end
end endgenerate

//生成TAGV
generate for (i=0; i<2; i=i+1) begin: tagv_ram_way
    tagv_sram u(
        .clka  (clk),
        .reset (reset),
        .ena   (way_tagv_ena[i]),
        .wea   (way_tagv_wea[i]),
        .addra (way_tagv_addra[i]),
        .dina  (way_tagv_dina[i]),
        .douta (way_tagv_douta[i])
    );
end endgenerate

endmodule

/*===============================各种模块===============================*/
module data_bank_sram
#(
    parameter WIDTH = 32    ,
    parameter DEPTH = 256
)
(
    input                  reset   ,
    input  [ 7:0]          addra   ,
    input                  clka    ,
    input  [31:0]          dina    ,
    output [31:0]          douta   ,
    input                  ena     ,
    input  [ 3:0]          wea      
);

reg [31:0] mem_reg [255:0];
reg [31:0] output_buffer;

always @(posedge clka) begin
    if (reset) begin: bank_reset
        integer i;
        for (i=0; i<256; i=i+1)
            mem_reg[i] <= 32'b0;
        output_buffer <= 32'b0;
    end
    else if (ena) begin
        if (|wea) begin
            if (wea[0]) begin
                mem_reg[addra][ 7: 0] <= dina[ 7: 0]; 
            end 

            if (wea[1]) begin
                mem_reg[addra][15: 8] <= dina[15: 8];
            end

            if (wea[2]) begin
                mem_reg[addra][23:16] <= dina[23:16];
            end

            if (wea[3]) begin
                mem_reg[addra][31:24] <= dina[31:24];
            end
        end
        else begin
            output_buffer <= mem_reg[addra];
        end
    end
end

assign douta = output_buffer;

endmodule 

module tagv_sram
#( 
    parameter WIDTH = 21    ,
    parameter DEPTH = 256
)
( 
    input                  reset   ,
    input  [ 7:0]          addra   ,
    input                  clka    ,
    input  [20:0]          dina    ,
    output [20:0]          douta   ,
    input                  ena     ,
    input                  wea 
);

reg [20:0] mem_reg [255:0];
reg [20:0] output_buffer;

always @(posedge clka) begin
    if (reset) begin: tagv_reset
        integer i;
        for (i=0; i<256; i=i+1)
            mem_reg[i] <= 21'b0;
        output_buffer <= 21'b0;
    end
    else if (ena) begin
        if (wea) begin
            mem_reg[addra] <= dina;
        end
        else begin
            output_buffer <= mem_reg[addra];
        end
    end
end

assign douta = output_buffer;

endmodule

module lsfr(
    input  wire       clk,
    input  wire       reset,
    output wire [1:0] random_val
);

reg [7:0] lsfr_val;

always @(posedge clk) begin
    if (reset)
        lsfr_val = 8'b10101010;
    else begin
        lsfr_val[0] <= lsfr_val[7];
        lsfr_val[1] <= lsfr_val[0] ^ lsfr_val[6];
        lsfr_val[2] <= lsfr_val[1];
        lsfr_val[3] <= lsfr_val[2] ^ lsfr_val[4];
        lsfr_val[4] <= lsfr_val[3] ^ lsfr_val[7];
        lsfr_val[5] <= lsfr_val[4];
        lsfr_val[6] <= lsfr_val[5];
        lsfr_val[7] <= lsfr_val[6]; 
    end
end

assign random_val = lsfr_val[6:5];

endmodule