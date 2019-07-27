`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/25 13:14:22
// Design Name: 
// Module Name: rob_entry
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


module rob_entry(
    input wire  clk,
    input wire  rst,
    input wire  clear,
    
    input wire          issue,
    input wire[140:0]   issue_inp,     
    input wire[141:0]   rob_inp,
    
    input wire          i_comp_avail,
    input wire          i_comp_cmeta,
    input wire[31:0]    i_nw_meta,
    input wire          i_comp_exception,
    input wire[4:0]     i_nw_excode,
    
    output wire[141:0]  rob_oup
    
);

wire[141:0]     inp;
assign inp = issue ? {1'b1, issue_inp} : rob_inp;

wire            i_result_reg;
wire[4:0]       i_result_reg_id;
wire[5:0]       i_result_regheap;
wire            i_component;
wire[2:0]       i_component_id;
wire            i_ri;
wire[5:0]       i_ri_id;
wire            i_rj;
wire[5:0]       i_rj_id;
wire[2:0]       i_commit_op;
wire[4:0]       i_excode;
wire[5:0]       i_uop;
wire[31:0]      i_meta;
wire[31:0]      i_pc;
wire[31:0]      i_j;
wire            i_ds;
wire            i_used;

assign i_result_reg = inp[0];
assign i_result_reg_id = inp[5:1];
assign i_result_regheap = inp[11:6];
assign i_component = inp[12];
assign i_component_id = inp[15:13];
assign i_ri = inp[16];
assign i_ri_id = inp[22:17];
assign i_rj = inp[23];
assign i_rj_id = inp[29:24];
assign i_commit_op = inp[32:30];
assign i_excode = inp[37:33];
assign i_uop = inp[43:38];
assign i_meta = inp[75:44];
assign i_pc = inp[107:76];
assign i_j = inp[139:108];
assign i_ds = inp[140];
assign i_used = inp[141];


reg         result_reg;
reg[4:0]    result_reg_id;
reg[5:0]    result_regheap;
reg         component;
reg[2:0]    component_id;
reg         ri, rj;
reg[5:0]    ri_id, rj_id;
reg[2:0]    commit_op;
reg[4:0]    excode;
reg[5:0]    uop;
reg[31:0]   meta, pc;
reg[31:0]   jump;
reg         ds, used;
assign rob_oup = { used, ds, jump, pc, meta, uop, excode, commit_op, rj_id, rj, ri_id, ri, component_id, component, result_regheap, result_reg_id, result_reg };

always @(posedge clk) begin
    if (rst || clear) begin
        result_reg <= 0;
        result_reg_id <= 0;
        result_regheap <= 0;
        component <= 0;
        component_id <= 0;
        ri <= 0;
        ri_id <= 0;
        rj <= 0;
        rj_id <= 0;
        commit_op <= 0;
        excode <= 0;
        uop <= 0;
        meta <= 0;
        pc <= 0;
        jump <= 0;
        ds <= 0;
        used <= 0;
    end
    else begin
        result_reg <= i_result_reg;
        result_reg_id <= i_result_reg_id;
        result_regheap <= i_result_regheap;
        component <= i_component;
        component_id <= i_component_id;
        ri <= i_ri;
        ri_id <= i_ri_id;
        rj <= i_rj;
        rj_id <= i_rj_id;
        commit_op <= i_commit_op;
        excode <= i_excode;
        uop <= i_uop;
        meta <= i_meta;
        pc <= i_pc;
        jump <= i_j;
        ds <= i_ds;
        used <= i_used;
        
        if (!issue) begin
            if (i_comp_avail) begin // 不需要再关注计算元件
                component <= 0;
            end
            
            if (i_comp_cmeta) begin
                meta <= i_nw_meta;
            end
            if (i_comp_exception) begin
                excode <= i_nw_excode;
            end
        end
    end
end

endmodule
