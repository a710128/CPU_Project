`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/26 01:25:02
// Design Name: 
// Module Name: branch
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


module branch(
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
    output wire         change_meta,
    output wire[31:0]   set_nw_meta,
    output wire         exc,
    output wire[4:0]    excode
);

parameter   STATUS_EMPTY = 0;
parameter   STATUS_CALC = 1;
parameter   STATUS_FINISHED = 2;

reg[1:0]        status;


reg         brc_ri, brc_rj;
reg[5:0]    brc_riid, brc_rjid;
reg[31:0]   brc_meta;
reg[5:0]    brc_uop;
reg[31:0]   brc_pc;


assign used = (status != STATUS_EMPTY) ? 1'b1 : 1'b0;
assign ri = brc_ri;
assign rj = brc_rj;
assign ri_id = brc_riid;
assign rj_id = brc_rjid;


reg[31:0]   brc_result;
reg         brc_set_meta;
reg[31:0]   brc_nw_meta;

assign avail = (status == STATUS_FINISHED) ? 1'b1 : 1'b0;
assign exc = 1'b0;
assign excode = 0;
assign result = brc_result;
assign change_meta = brc_set_meta;
assign set_nw_meta = brc_nw_meta;

always @(posedge clk) begin
    if (rst || clear) begin
        status <= STATUS_EMPTY;
    end
    else begin
        case(status)
            2'd0: begin // EMPTY
                if (issue) begin    // 发射
                    brc_ri <= issue_vec[16];
                    brc_riid <= issue_vec[22:17];
                    brc_rj <= issue_vec[23];
                    brc_rjid <= issue_vec[29:24];
                    brc_meta <= issue_vec[75:44];
                    brc_uop <= issue_vec[43:38];
                    brc_pc <= issue_vec[107:76];
                    status <= STATUS_CALC;
                end
            end
            2'd1: begin
                if (ri_avail && rj_avail) begin
                    
                    status <= STATUS_FINISHED;
                    brc_set_meta <= 1;
                    brc_result <= brc_pc + 32'd8;
                    
                    case(brc_uop)
                    6'd0,  6'd1: begin // BGEZ(AL)
                        if (~ri_val[31]) begin  // >= 0
                            brc_nw_meta <= brc_pc + 32'd4 + {brc_meta[29:0], 2'b0}; // PC delay slot + offset
                        end
                        else begin
                            brc_nw_meta <= brc_pc + 32'd8;
                        end
                    end
                    6'd2, 6'd3: begin // BLTZ(AL)
                        if (ri_val[31]) begin   // < 0
                            brc_nw_meta <= brc_pc + 32'd4 + {brc_meta[29:0], 2'b0}; // PC delay slot + offset
                        end
                        else begin
                            brc_nw_meta <= brc_pc + 32'd8;
                        end
                    end
                    6'd4: begin // BLEZ
                        if ( ri_val[31] || (ri_val == 32'b0) ) begin   // <= 0
                            brc_nw_meta <= brc_pc + 32'd4 + {brc_meta[29:0], 2'b0}; // PC delay slot + offset
                        end
                        else begin
                            brc_nw_meta <= brc_pc + 32'd8;
                        end
                    end
                    6'd5: begin // BGTZ
                        if ( !((ri_val[31]) || (ri_val == 32'b0)) ) begin   // > 0
                            brc_nw_meta <= brc_pc + 32'd4 + {brc_meta[29:0], 2'b0}; // PC delay slot + offset
                        end
                        else begin
                            brc_nw_meta <= brc_pc + 32'd8;
                        end
                    end
                    6'd6: begin // BNE
                        if ( !(ri_val == rj_val) ) begin   // <= 0
                            brc_nw_meta <= brc_pc + 32'd4 + {brc_meta[29:0], 2'b0}; // PC delay slot + offset
                        end
                        else begin
                            brc_nw_meta <= brc_pc + 32'd8;
                        end
                    end
                    6'd7: begin // BEQ
                        if ( ri_val == rj_val ) begin
                            brc_nw_meta <= brc_pc + 32'd4 + {brc_meta[29:0], 2'b0}; // PC delay slot + offset
                        end
                        else begin
                            brc_nw_meta <= brc_pc + 32'd8;
                        end
                    end
                    6'd8, 6'd9: begin // JAL, J
                        brc_nw_meta <= {brc_pc[31:28], brc_meta[25:0], 2'b0 };
                    end
                    6'd10, 6'd11: begin // JALR, JR
                        brc_nw_meta <= ri_val;
                    end
                    endcase
                end
            end
            2'd2: begin // Finished
                status <= STATUS_EMPTY;
            end
        endcase
    end
end

endmodule
