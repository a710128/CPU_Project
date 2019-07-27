`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/25 23:38:16
// Design Name: 
// Module Name: alu
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


module alu(
    input wire      clk,
    input wire      rst,
    input wire      clear,
    
    // 获取发射信息
    input wire          issue,
    input wire[140:0]   issue_vec,
    
    // 获取寄存器状态
    input wire[31:0]    ri_val,
    input wire          ri_avail,
    input wire[31:0]    rj_val,
    input wire          rj_avail,
    
    // 输出状态
    output wire         used,
    output wire         ri,
    output wire         rj,
    output wire[5:0]    ri_id,
    output wire[5:0]    rj_id,
    
    // 输出结果
    output wire[31:0]   result,
    output wire         avail,
    output wire         change_meta,    // disabled
    output wire[31:0]   set_nw_meta,    // disalbed
    output wire         exc,
    output wire[4:0]    excode
    
);

reg[2:0] status;

parameter STATUS_EMPTY = 0;
parameter STATUS_CALC = 1;
parameter STATUS_FINISHED = 2;


reg         alu_ri, alu_rj;
reg[5:0]    alu_riid, alu_rjid;
reg[31:0]   alu_meta;
reg[5:0]    alu_uop;


assign used = (status != STATUS_EMPTY) ? 1'b1 : 1'b0;
assign ri = alu_ri;
assign rj = alu_rj;
assign ri_id = alu_riid;
assign rj_id = alu_rjid;


reg[31:0]   alu_result;
reg         alu_exc;
reg[4:0]    alu_excode;
assign avail = (status == STATUS_FINISHED) ? 1'b1 : 1'b0;
assign result = alu_result;

assign change_meta = 0;
assign set_nw_meta = 0;
assign exc = alu_exc;
assign excode = alu_excode;

// others

wire[32:0]      ext_ri = {ri_val[31], ri_val[31:0]};
wire[32:0]      ext_rj = {rj_val[31], rj_val[31:0]};
wire[32:0]      ext_meta = { alu_meta[31], alu_meta[31:0] };
wire[32:0]      ext_addi = ext_ri + ext_meta;
wire[32:0]      ext_sub = ext_ri - ext_rj;
wire[32:0]      ext_add = ext_ri + ext_rj;


always @(posedge clk) begin
    if (rst || clear) begin
        status <= STATUS_EMPTY;
    end
    else begin
        case(status)
            3'd0:   begin
                if (issue) begin    // 发射
                    alu_ri <= issue_vec[16];
                    alu_riid <= issue_vec[22:17];
                    alu_rj <= issue_vec[23];
                    alu_rjid <= issue_vec[29:24];
                    alu_meta <= issue_vec[75:44];
                    alu_uop <= issue_vec[43:38];
                    status <= STATUS_CALC;
                end
            end
            3'd1: begin
                if (ri_avail && rj_avail) begin
                    status <= STATUS_FINISHED;
                    alu_exc <= 0;
                    alu_excode <= 0;
                    
                    case(alu_uop)
                        6'd0: begin // LUI
                            alu_result <= {alu_meta[15:0], 16'b0};
                        end
                        6'd1: begin // SLTIU
                            alu_result <= (ri_val < alu_meta) ? 32'b1 : 32'b0;
                        end
                        6'd2: begin // SLTI
                            alu_result <= ($signed(ri_val) < $signed(alu_meta)) ? 32'b1 : 32'b0;
                        end
                        6'd3: begin // XORI
                            alu_result <= ri_val ^ alu_meta;
                        end
                        6'd4: begin // ORI
                            alu_result <= ri_val | alu_meta;
                        end
                        6'd5: begin // ANDI
                            alu_result <= ri_val & alu_meta;
                        end
                        6'd6: begin // ADDIU
                            alu_result <= ri_val + alu_meta;
                        end
                        6'd7: begin // ADDI
                            if (ext_addi[32] == ext_addi[31]) begin
                                alu_result <= ext_addi[31:0];
                            end
                            else begin
                                alu_exc <= 1;
                                alu_excode <= 5'h0c;    // Overflow
                            end
                        end
                        6'd8: begin // MOVZ
                            alu_exc <= 1;
                            alu_excode <= 5'h0a;    // 暂时不支持, RI
                        end
                        6'd9: begin // SLTU
                            alu_result <= (ri_val < rj_val) ? 32'b1 : 32'b0;
                        end
                        6'd10: begin    // SLT
                            alu_result <= ($signed(ri_val) < $signed(rj_val)) ? 32'b1 : 32'b0;
                        end
                        6'd11: begin    // SRAV
                            alu_result <= ($signed(rj_val)) >>> ri_val[4:0];
                        end
                        6'd12: begin    // SRA
                            alu_result <= ($signed(rj_val)) >>> alu_meta[4:0];
                        end
                        6'd13: begin    // SRLV
                            alu_result <= rj_val >> ri_val[4:0];
                        end
                        6'd14: begin    // SRL
                            alu_result <= rj_val >> alu_meta[4:0];
                        end
                        6'd15: begin    // SLLV
                            alu_result <= rj_val << ri_val[4:0];
                        end
                        6'd16: begin    // SLL
                            alu_result <= rj_val << alu_meta[4:0];
                        end
                        6'd17: begin    // NOR
                            alu_result <= ~(ri_val | rj_val);
                        end
                        6'd18: begin    // XOR
                            alu_result <= ri_val ^ rj_val;
                        end
                        6'd19: begin    // OR
                            alu_result <= ri_val | rj_val;
                        end
                        6'd20: begin    // AND
                            alu_result <= ri_val & rj_val;
                        end
                        6'd21: begin    // SUBU
                            alu_result <= ri_val - rj_val;
                        end
                        6'd22: begin    // SUB
                            if (ext_sub[32] == ext_sub[31]) begin
                                alu_result <= ext_sub[31:0];
                            end
                            else begin
                                alu_exc <= 1;
                                alu_excode <= 5'h0c;    // Overflow
                            end
                        end
                        6'd23: begin    // ADDU
                            alu_result <= ri_val + rj_val;
                        end
                        6'd24: begin    // ADD
                            if (ext_add[32] == ext_add[31]) begin
                                alu_result <= ext_add[31:0];
                            end
                            else begin
                                alu_exc <= 1;
                                alu_excode <= 5'h0c;    // Overflow
                            end
                        end
                        default: ;
                    endcase
                end
            end
            3'd2: begin // Finished 清空
                status <= STATUS_EMPTY;
            end
            default: ;
        endcase
    end
end

endmodule
