`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/26 15:07:59
// Design Name: 
// Module Name: branch_predictor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module branch_predictor(
    input  wire         clk,
    input  wire         rst,
    input  wire         clear,
    
    input  wire[7:0]    current_entryHI,
    
    input  wire         if_skip,
    input  wire         noinst,
    input  wire[31:0]   inst,
    input  wire[31:0]   pc,
    
    input  wire         feed_we,
    input  wire[31:0]   feed_pc,
    input  wire[31:0]   feed_res,
    
    output reg [31:0]   pc_pred
);

parameter STATUS_INIT_0 = 0;
parameter STATUS_CLEAR = 1;
parameter STATUS_NORMAL = 2;
parameter STATUS_INIT_1 = 3;
parameter INIT_PC = 32'hBFC00000;
//parameter INIT_PC = 32'h80000000;

reg[3:0]    status = STATUS_INIT_0;
reg[255:0]  valid;
reg[61:0]   bp_line[255:0];

wire        no_jump;


wire[7:0]   feed_pc_index = feed_pc[9:2] + 8'b1;
wire[29:0]  feed_pc_tag = { feed_pc[31:10], current_entryHI[7:0] };
wire[61:0]  feed_bp_line = bp_line[feed_pc_index];
wire        feed_match = valid[feed_pc_index] && ( feed_bp_line[29:0] == feed_pc_tag );

assign  no_jump = (feed_pc + 32'd8) == feed_res;

reg[31:0]   last_pred;


always @(posedge clk) begin
    if (rst) begin
        valid <= 256'b0;
        status <= STATUS_INIT_0;
    end
    else if (clear) begin
        status <= STATUS_CLEAR;
    end
    else if (status == STATUS_INIT_0) begin
        status <= STATUS_INIT_1;
    end
    else begin
        status <= STATUS_NORMAL;
    end
    
    if (feed_we) begin
        if (feed_match) begin
            bp_line[feed_pc_index] <= {feed_bp_line[61], ~no_jump, feed_bp_line[59:0]};
        end
        else begin
            valid[feed_pc_index] <= 1'b1;
            bp_line[feed_pc_index] <= { 1'b0, ~no_jump, feed_res[31:2], feed_pc_tag };
        end
    end
    
    last_pred <= pc_pred;
end

wire[7:0]       pc_index = pc[9:2];
wire[29:0]      pc_tag = { pc[31:10], current_entryHI[7:0] };
wire[61:0]      pc_bp_line = bp_line[pc_index];
wire            pc_match = valid[pc_index] && (pc_bp_line[29:0] == pc_tag);
wire            pred_jump = pc_match && (!(pc_bp_line[61:60] == 2'b0));

wire[5:0]   op = inst[31:26];
wire[5:0]   func = inst[5:0];
wire        is_j        =   (op == 6'b000010);
wire        is_jal      =   (op == 6'b000011);
wire        is_jr       =   (op == 6'b000000) && (func == 6'b001000) && (inst[20:11] == 5'b00000);
wire        is_jalr     =   (op == 6'b000000) && (func == 6'b001001) && (inst[20:16] == 5'b00000);
wire        is_beq      =   (op == 6'b000100);
wire        is_bne      =   (op == 6'b000101);
wire        is_bgtz     =   (op == 6'b000111) && (inst[20:16] == 5'b00000);
wire        is_blez     =   (op == 6'b000110) && (inst[20:16] == 5'b00000);
wire        is_bltz     =   (op == 6'b000001) && (inst[20:16] == 5'b00000);
wire        is_bltzal   =   (op == 6'b000001) && (inst[20:16] == 5'b10000);
wire        is_bgez     =   (op == 6'b000001) && (inst[20:16] == 5'b00001);
wire        is_bgezal   =   (op == 6'b000001) && (inst[20:16] == 5'b10001);


always @(*) begin
    if (status == STATUS_INIT_0) begin
        pc_pred <= INIT_PC;
    end
    else if (status == STATUS_INIT_1) begin
        pc_pred <= INIT_PC + 32'd4;
    end
    else if (status == STATUS_CLEAR) begin
        pc_pred <= pc + 32'd4;
    end
    else begin
        if (if_skip) begin  // 如果当前IF被跳过，则保持预测不变
            pc_pred <= last_pred;
        end
        else
        if (noinst) begin   // 不会执行到这个if里
            pc_pred <= last_pred;
        end
        else if (is_j || is_jal) begin
            pc_pred <= { pc[31:28], inst[25:0], 2'b0 };
        end
        else if (is_jr || is_jalr || is_beq || is_bne || is_bgtz || is_blez || is_bltz || is_bltzal || is_bgez || is_bgezal) begin
            if (pred_jump) begin
                pc_pred <= { pc_bp_line[59:30], 2'b0 };
            end
            else begin
                pc_pred <= pc + 32'd4;
            end
        end
        else begin
            pc_pred <= pc + 32'd4;
        end

    end
end

endmodule
