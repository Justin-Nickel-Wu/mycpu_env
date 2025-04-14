`include "constants.h"

module IF_stage(
    input   wire                         clk,
    input   wire                         reset,

    input   wire                         csr_reset,
    input   wire [31:0]                  ex_entry,

    output  wire                         inst_sram_req,
    output  wire                         inst_sram_wr,
    output  wire [ 1:0]                  inst_sram_size,
    output  wire [ 3:0]                  inst_sram_wstrb,
    output  wire [31:0]                  inst_sram_addr,
    output  wire [31:0]                  inst_sram_wdata,
    input   wire                         inst_sram_addr_ok,
    input   wire                         inst_sram_data_ok,
    input   wire [31:0]                  inst_sram_rdata, 

    input   wire                         to_IF_valid,
    input   wire                         ID_allow_in,
    output  wire                         IF_to_ID_valid,
    output  wire [`to_ID_data_width-1:0] to_ID_data,
    input   wire [`br_data_width-1:0]    br_data
);

wire  IF_valid;
wire IF_ready_go;
wire IF_allow_in;

reg  [31:0] pc;
reg  [31:0] inst_r;
wire [31:0] inst;

wire [31:0] nextpc;
wire [31:0] seq_pc;
wire        br_taken;
wire [31:0] br_target;
wire        need_jump;
wire        ex_ADEF;

localparam REQ           = 0,
           WAIT_FOR_OK   = 1,
           WAIT_FOR_ID   = 2,
           NEED_CANCEL   = 3;

reg  [1:0] IF_state;
reg        inst_req;

always @(posedge clk) begin
    if (reset) begin
        IF_state <= REQ;
        inst_req <= 1'b1;
        pc <= 32'h1c000000;
    end else 
        case (IF_state)
            REQ: begin
                if (inst_sram_addr_ok == 1'b1) begin
                    if (need_jump) begin
                        IF_state <= NEED_CANCEL;
                        inst_req <= 1'b0;
                        pc <= nextpc;
                    end
                    else begin
                        IF_state <= WAIT_FOR_OK;
                        inst_req <= 1'b0;
                    end
                end else if (need_jump) begin
                    pc <= nextpc;
                end
            end

            WAIT_FOR_OK: begin
                if (inst_sram_data_ok == 1'b1) begin
                    inst_r <= inst_sram_rdata;

                    if (need_jump) begin
                        IF_state <= REQ;
                        inst_req <= 1'b1;
                        pc <= nextpc;
                    end else begin
                        if (ID_allow_in == 1'b1) begin //若ID允许输入，则直接发射
                            IF_state <= REQ;
                            inst_req <= 1'b1;
                            pc <= nextpc;
                        end else begin
                            IF_state <= WAIT_FOR_ID;
                        end
                    end
                end else if (need_jump) begin
                    IF_state <= NEED_CANCEL;
                    pc <= nextpc;
                end
            end

            WAIT_FOR_ID: begin
                if (need_jump) begin
                    IF_state <= REQ;
                    inst_req <= 1'b1;
                    pc <= nextpc;
                end else if (ID_allow_in == 1'b1) begin //无论是否jump都进入REQ
                    IF_state <= REQ;
                    inst_req <= 1'b1;
                    pc <= nextpc;
                end
            end

            //如果因为跳转指令进入need_cancel状态，可能等待时又收到csr_reset信号，此时入口应为ex_entry,需覆盖
            //反之因为csr_reset信号进入need_cancel状态，不可能再次需要改变入口
            NEED_CANCEL: begin
                if (need_jump)
                    pc <= nextpc;
                if (inst_sram_data_ok == 1'b1) begin
                    IF_state <= REQ;
                    inst_req <= 1'b1;
                end
            end
        endcase
end

//一些inst_sram无需使用的信号
assign inst_sram_req = inst_req;
assign inst_sram_wr = 1'b0;
assign inst_sram_size = 2'b10;
assign inst_sram_wstrb = 4'b0000;
assign inst_sram_addr = pc;
assign inst_sram_wdata = 32'b0;

//控制阻塞信号
assign IF_valid = ~reset;
assign IF_ready_go = (IF_state == WAIT_FOR_OK && inst_sram_data_ok == 1'b1) || (IF_state == WAIT_FOR_ID);
assign IF_allow_in = ~IF_valid | (IF_ready_go & ID_allow_in) | csr_reset;
assign IF_to_ID_valid = IF_valid & IF_ready_go;
assign need_jump = csr_reset || br_taken;

assign inst = ex_ADEF ? 32'b0 : 
              inst_sram_data_ok ? inst_sram_rdata :
                                  inst_r;
assign {br_taken, br_target} = br_data;
assign seq_pc       = pc + 32'h4;
assign nextpc       = csr_reset ? ex_entry  :
                      br_taken  ? br_target : 
                                  seq_pc;
assign ex_ADEF      = pc[1:0] != 2'b00;

//TODO：赋全0后续会被标记上指令不存在例外，这样是否会出现问题？

//传递数据
assign to_ID_data = {pc, 
                     inst,
                     ex_ADEF};

endmodule