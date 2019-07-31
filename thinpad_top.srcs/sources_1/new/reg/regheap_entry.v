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
    input wire[5:0]             reg_id,         // �Ĵ���id
    
    // �Ĵ����ѷ���
    input  wire                 set_reg_a,      // ����
    input  wire[4:0]            set_reg_R,
    input  wire                 set_commit_wb,  // commit �׶�ʹ������ͨ·��д
    input  wire[2:0]            set_component_id,
    
    // ������״̬��ȡ�����¼Ĵ���ֵ
    output wire[2:0]            reg_component_id,           // ��ǰ����������id
    input  wire                 reg_component_available,    // ��������ֵ�Ƿ����
    input  wire[31:0]           reg_component_val,          // �������Ľ��
    
    // �Ĵ�����״̬
    output wire                 reg_used,           // ��ǰ�Ĵ����Ƿ�ʹ��
    output wire                 reg_available,      // �Ĵ�����ֵ�Ƿ����
    output wire[31:0]           reg_val,            // �Ĵ�����ֵ
    
    // �Ĵ���״̬
    input  wire                 force_update,       // ǿ�Ƹ���
    input  wire[31:0]           force_value,         // ǿ�Ƹ��µ�ֵ
    
    // Commit ��Ϣ��ȡ
    input   wire                commit,
    input   wire[4:0]           commit_regid,
    input   wire[5:0]           commit_regheap
);


reg[2:0]    assign_component;
reg[4:0]    assign_reg;
reg         used;
reg[31:0]   val;
reg         available;
reg         commit_wb;  // ��commit�׶�ʹ������ͨ·��д
reg         last_commit;    // �Ƿ������һ��commit�ļĴ���

assign reg_component_id = assign_component;
assign reg_used = used;
assign reg_available = (assign_reg == 0) ? used : available;
assign reg_val = (assign_reg == 0) ? 0 : val;



always @(posedge clk) begin
    if (rst) begin
        val <= 0;
        commit_wb <= 0;
        last_commit <= 1;
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
        if (commit && used && (commit_regid == assign_reg)) begin // ��clear��ͬʱ��commit���ұ�ʹ�ã��Һ��Լ���صļĴ������ύ 
            if (commit_regheap == reg_id) begin // �Լ����ύ
                last_commit <= 1;
                // ɶҲ����
                if (commit_wb && force_update) begin
                    available <= 1;
                    val <= force_value;
                end
            end
            else begin
                // �����Լ����ύ�����
                assign_reg <= 0;
                used <= 0;
                val <= 0;
                available <= 0;
                assign_component <= 0;
                commit_wb <= 0;
                last_commit <= 0;
            end
        end
        else begin  // Ĭ�����
            if (last_commit) begin // ��ǰ�Ĵ�����ֵΪ���commit��ֵ
                // do nothing
            end
            else begin  // ��ռĴ���״̬
                assign_reg <= 0;
                used <= 0;
                val <= 0;
                available <= 0;
                assign_component <= 0;
                commit_wb <= 0;
                last_commit <= 0;
            end
        end
        
    end
    else begin
        if (used) begin
            // �Ѿ�������
            if (available) begin    // �Ѿ����
                // ɶҲ����
                if (last_commit) begin  // �Ѿ���commit
                    if (commit && (commit_regid == assign_reg)) begin   // ����ĸ���
                        // �ͷżĴ���
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
                    if (commit && (commit_regid == assign_reg) && (commit_regheap == reg_id)) begin // �Լ����ύ
                        last_commit <= 1;
                    end
                end
                
            end
            else begin  // ��δ���
                if (commit_wb) begin
                    if (force_update) begin
                        available <= 1;
                        val <= force_value;
                        
                        if (commit && (commit_regid == assign_reg) && (commit_regheap == reg_id)) begin // ���µ�ͬʱ�ύ
                            last_commit <= 1;
                        end
                    end
                end
                else if (reg_component_available) begin // �������Ѿ����
                    available <= 1;
                    val <= reg_component_val;
                end
                else begin
                    // ɶҲ����
                end
            end
        end
        else begin
            // δ������
            if (set_reg_a) begin    // ����
                assign_reg <= set_reg_R;
                assign_component <= set_component_id;
                used <= 1;
                val <= 0;
                available <= 0;
                commit_wb <= set_commit_wb;
                last_commit <= 0;
            end
            else begin
                // ɶҲ����
            end
            
        end
    end
    
end

endmodule