`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/24 17:59:24
// Design Name: 
// Module Name: regheap_entry
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


module regheap_entry(
    input wire                  clk,
    input wire                  rst,
    input wire                  clear,
    input wire[5:0]             reg_id,         // 寄存器id
    
    // 寄存器堆分配
    input  wire                 set_reg_a,      // 分配
    input  wire[4:0]            set_reg_R,
    input  wire                 set_commit_wb,  // commit 阶段使用特殊通路回写
    input  wire[2:0]            set_component_id,
    
    // 运算器状态获取，更新寄存器值
    output wire[2:0]            reg_component_id,           // 当前关联运算器id
    input  wire                 reg_component_available,    // 运算器的值是否可用
    input  wire[31:0]           reg_component_val,          // 运算器的结果
    
    // 寄存器堆状态
    output wire                 reg_used,           // 当前寄存器是否被使用
    output wire                 reg_available,      // 寄存器的值是否可用
    output wire[31:0]           reg_val,            // 寄存器的值
    
    // 寄存器状态
    input  wire                 force_update,       // 强制更新
    input  wire[31:0]           force_value,         // 强制更新的值
    
    // Commit 信息获取
    input   wire                commit,
    input   wire[4:0]           commit_regid,
    input   wire[5:0]           commit_regheap
);


reg[2:0]    assign_component;
reg[4:0]    assign_reg;
reg         used;
reg[31:0]   val;
reg         available;
reg         commit_wb;  // 在commit阶段使用特殊通路回写
reg         last_commit;    // 是否是最后一次commit的寄存器

assign reg_component_id = assign_component;
assign reg_used = used;
assign reg_available = (assign_reg == 0) ? 1 : available;
assign reg_val = (assign_reg == 0) ? 0 : val;

always @(posedge clk) begin
    if (rst) begin
        val <= 0;
        commit_wb <= 0;
        last_commit <= 0;
        if (reg_id < 32) begin
            assign_reg <= reg_id;
            used <= 1;
            available <= 1;
        end
        else begin
            assign_reg <= 0;
            used <= 0;
            available <= 0;
        end
    end
    else if (clear) begin
        if (last_commit) begin // 当前寄存器的值为最后commit的值
            // do nothing
        end
        else begin  // 清空寄存器状态
            assign_reg <= 0;
            available <= 0;
            used <= 0;
            val <= 0;
            commit_wb <= 0;
        end
    end
    else begin
        if (used) begin
            // 已经被分配
            if (available) begin    // 已经完成
                // 啥也不干
                if (last_commit) begin  // 已经被commit
                    if (commit && (commit_regid == assign_reg)) begin   // 被别的覆盖
                        // 释放寄存器
                        assign_reg <= 0;
                        used <= 0;
                        val <= 0;
                        available <= 0;
                        assign_component <= 0;
                        commit_wb <= 0;
                        last_commit <= 0;
                    end
                end
                else begin
                    if (commit && (commit_regid == assign_reg) && (commit_regheap == reg_id)) begin // 自己被提交
                        last_commit <= 1;
                    end
                end
                
            end
            else begin  // 还未完成
                if (set_commit_wb) begin
                    if (force_update) begin
                        available <= 1;
                        val <= force_value;
                    end
                end
                else if (reg_component_available) begin // 运算器已经完成
                    available <= 1;
                    val <= reg_component_val;
                end
                else begin
                    // 啥也不干
                end
            end
        end
        else begin
            // 未被分配
            if (set_reg_a) begin    // 分配
                assign_reg <= set_reg_R;
                assign_component <= set_component_id;
                used <= 1;
                val <= 0;
                available <= 0;
                commit_wb <= set_commit_wb;
                last_commit <= 0;
            end
            else begin
                // 啥也不干
            end
            
        end
    end
    
end

endmodule
