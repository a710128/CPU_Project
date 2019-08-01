`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/25 14:49:01
// Design Name: 
// Module Name: rob_commit
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


module rob_commit(
    // BASE
    input wire  clk,
    input wire  rst,
    input wire  clear,
    input wire  period0,
    
    input wire          issue,
    
    input wire[140:0]   issue_inp,     
    input wire[141:0]   rob_inp,
    
    input wire          i_comp_avail,
    input wire          i_comp_cmeta,
    input wire[31:0]    i_nw_meta,
    input wire          i_comp_exception,
    input wire[4:0]     i_nw_excode,
    
    output wire[141:0]  rob_oup,
    
    // EXT
    output reg          commit,
    output reg          commit_upd,             // commit 是否需要修改寄存器
    output reg[4:0]     commit_reg,
    output reg[5:0]     commit_regheap,
    
    input wire          result_avail,           // 是否已经计算出结果
    input wire[31:0]    ri_val,
    input wire[31:0]    rj_val,        
    input wire[3:0]     i_status,               // 状态
    output wire[3:0]    o_status,
    
    input wire          intq,                   // 是否有外部中断
    output reg          tlb_exc,
    output reg          normal_exc,
    input wire[31:0]    cp0_SR,
    // Branch
    output reg          change_pc_imm,
    output reg          change_pc_ds,           // 在下一个延迟槽时修改PC
    output reg[31:0]    change_pc_to,
    output reg          feed_to_bp,             // 是否更新分支预测表
    output reg[31:0]    feed_bp_res,            // 分支跳转目的地址
    
    // MEM
    output reg          mem_ce,                 // 需要访存
    output reg          mem_write,              // 是否写访存
    output reg[31:0]    mem_vaddr,              // 访存地址
    output reg[4:0]     mem_bytemode,           // 字节模式
    output reg[31:0]    mem_write_data,         // 写出数据
    input wire[31:0]    mem_read_data,          // 读入数据
    input wire          mem_avail,              // 操作完成
    input wire          mem_tlbmiss,            // TLB Miss
    input wire          mem_modify_ex,
    
    // HI LO
    input wire[31:0]    reg_hi,
    input wire[31:0]    reg_lo,
    output reg          upd_hi,
    output reg          upd_lo,
    output reg[31:0]    upd_hi_val,
    output reg[31:0]    upd_lo_val,
    
    // force update
    output reg          force_upd,
    output reg[31:0]    force_upd_val,
    
    // MUL DIV
    input wire[63:0]    muldiv_res,
    output reg          muldiv_clear,
    
    // CP0
    output reg          cp0_ce,
    output reg[2:0]     cp0_inst,
    output reg[4:0]     cp0_param,
    output reg[31:0]    cp0_putval,
    input wire[31:0]    cp0_result        
);

parameter STATUS_WAIT = 0;  // 等待运算完成
parameter STATUS_MEM0 = 1;
parameter STATUS_CP0_0  = 2;
parameter STATUS_MEM1 = 3;
parameter STATUS_CP0_1  = 4;
parameter STATUS_ERET_0 = 5;
parameter STATUS_ERET_1 = 6;
parameter STATUS_FORCE_COMMIT = 7;

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
reg ds, used;
reg[3:0] status;

assign rob_oup = { used, ds, jump, pc, meta, uop, excode, commit_op, rj_id, rj, ri_id, ri, component_id, component, result_regheap, result_reg_id, result_reg };
assign o_status = status;

wire[31:0]  sl_addr = $signed(ri_val) + i_meta;
wire        is_kernel = (cp0_SR[1] || (cp0_SR[4:3] == 2'b00));
//wire        commit_wb = (i_component == 0) && (!result_avail);  // 无关联计算元件且变量未完成


always @(posedge clk) begin
    commit <= 0;
    status <= STATUS_WAIT;
    tlb_exc <= 0;
    normal_exc <= 0;
    change_pc_imm <= 0;
    change_pc_ds <= 0;
    feed_to_bp <= 0;
    mem_ce <= 0;
    upd_hi <= 0;
    upd_lo <= 0;
    force_upd <= 0;
    muldiv_clear <= 0;
    cp0_ce <= 0;
    
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
           
        // ext
        if (!issue) begin
            if (i_comp_avail) begin
                component <= 0;
            end
            
            if (i_comp_cmeta) begin
                meta <= i_nw_meta;
            end
            if (i_comp_exception) begin
                excode <= i_nw_excode;
            end
        
            if (!i_used) begin
            end
            //else if ((!result_avail) && (!commit_wb)) begin    // 还未计算出结果
            else if (i_component) begin    // 还未计算出结果
                if (intq) begin // 外部中断，在等待结果时候遇到外部中断则直接处理
                    normal_exc <= 1;
                    excode <= 0;
                end
                else begin
                    status <= STATUS_WAIT;
                end
            end
            else begin
                if (i_status == STATUS_WAIT) begin
                    // 刚刚完成计算
                    // 1. 检查异常
                    // 2. 特权判断
                    if (intq) begin // 外部中断，在检查异常阶段遇到中断则直接处理（不提交）
                        normal_exc <= 1;
                        excode <= 0;
                    end
                    else if (i_excode) begin // 有异常
                        // （将会触发clear所以不设置status）
                        if (i_excode == 2) begin
                            tlb_exc <= 1; // TLB 异常 
                        end
                        else begin
                            normal_exc <= 1;
                        end
                    end
                    else if ( !is_kernel && (i_pc >= 32'h80000000) ) begin
                        excode <= 5'h0a;      // RI
                        normal_exc <= 1;
                    end
                    else begin
                        case (i_commit_op)
                            3'd0: begin // No op
                                // 直接提交（不需要修改status）
                                commit <= 1;
                                commit_upd <= i_result_reg;
                                commit_reg <= i_result_reg_id;
                                commit_regheap <= i_result_regheap;
                            end
                            3'd1: begin //  Branch
                                // 直接提交
                                commit <= 1;
                                commit_upd <= i_result_reg;
                                commit_reg <= i_result_reg_id;
                                commit_regheap <= i_result_regheap;
                                // i_meta = Jump TO PC
                                // change_pc_ds <= 1;
                                
                                feed_to_bp <= 1;            // 更新分支预测表
                                feed_bp_res <= i_meta;
                                
                                if (i_meta == i_j) begin // 预测正确
                                    // 啥也不干
                                end
                                else begin
                                    if (i_meta[1:0] == 2'b00) begin
                                        change_pc_ds <= 1; // 下一个延迟槽提交时修改PC
                                        change_pc_to <= i_meta;
                                    end
                                    else begin
                                        feed_to_bp <= 0; // 不更新！！
                                        commit <= 0;     // 不提交
                                        excode <= 5'h04;      // AdEL
                                        normal_exc <= 1;
                                        mem_vaddr <= i_meta;
                                    end
                                end
                            end
                            3'd2: begin // MEM  （需要写回内存）
                                // 不提交，进入内存处理阶段
                                commit <= 0;
                                
                                if (period0) begin  // 等待第二阶段
                                    status <= STATUS_MEM0;
                                end
                                
                                mem_vaddr <= sl_addr;
                                case(i_uop)
                                    6'd0: begin // SB
                                        mem_ce <= 1;
                                        mem_write <= 1; 
                                        mem_bytemode <= {1'b0, sl_addr[1] & sl_addr[0], sl_addr[1] & ~sl_addr[0], ~sl_addr[1] & sl_addr[0], ~sl_addr[1] & ~sl_addr[0]};
                                        mem_write_data <= rj_val;
                                    end
                                    6'd1: begin // SH
                                        if (sl_addr[0] == 1'b0) begin
                                            mem_ce <= 1;
                                            mem_write <= 1; 
                                            mem_bytemode <= {1'b0, sl_addr[1], sl_addr[1], ~sl_addr[1], ~sl_addr[1]};
                                            mem_write_data <= rj_val;
                                        end
                                        else begin
                                            excode <= 5'h05; // AdES
                                        end
                                    end
                                    6'd2: begin // SW
                                        if (sl_addr[1:0] == 2'b00) begin
                                            mem_ce <= 1;
                                            mem_write <= 1; 
                                            mem_bytemode <= 5'b01111;
                                            mem_write_data <= rj_val;
                                        end
                                        else begin
                                            excode <= 5'h05; // AdES
                                        end
                                    end
                                    6'd3: begin // LBU
                                        mem_ce <= 1;
                                        mem_write <= 0; 
                                        mem_bytemode <= {1'b1, sl_addr[1] & sl_addr[0], sl_addr[1] & ~sl_addr[0], ~sl_addr[1] & sl_addr[0], ~sl_addr[1] & ~sl_addr[0]};
                                    end
                                    6'd4: begin // LB
                                        mem_ce <= 1;
                                        mem_write <= 0; 
                                        mem_bytemode <= {1'b0, sl_addr[1] & sl_addr[0], sl_addr[1] & ~sl_addr[0], ~sl_addr[1] & sl_addr[0], ~sl_addr[1] & ~sl_addr[0]};
                                    end
                                    6'd5: begin // LHU
                                        if (sl_addr[0] == 1'b0) begin
                                            mem_ce <= 1;
                                            mem_write <= 0; 
                                            mem_bytemode <= {1'b1, sl_addr[1], sl_addr[1], ~sl_addr[1], ~sl_addr[1]};
                                        end
                                        else begin
                                            excode <= 5'h04; // AdEL
                                        end
                                    end
                                    6'd6: begin // LH
                                        if (sl_addr[0] == 1'b0) begin
                                            mem_ce <= 1;
                                            mem_write <= 0; 
                                            mem_bytemode <= {1'b0, sl_addr[1], sl_addr[1], ~sl_addr[1], ~sl_addr[1]};
                                        end
                                        else begin
                                            excode <= 5'h04; // AdEL
                                        end
                                    end
                                    6'd7: begin // LW
                                        if (sl_addr[1:0] == 2'b00) begin
                                            mem_ce <= 1;
                                            mem_write <= 0;
                                            mem_bytemode <= 5'b01111;
                                        end
                                        else begin
                                            excode <= 5'h04; // AdEL
                                        end
                                    end
                                    default: ;
                                endcase
                            end
                            3'd3: begin // MFHI/LO
                                status <= STATUS_FORCE_COMMIT;
                                force_upd <= 1;
                                force_upd_val <= i_meta[0] ? reg_lo : reg_hi;
                            end
                            3'd4: begin // MTHI/LO
                                commit <= 1;
                                commit_upd <= 0;
                                upd_hi <= ~i_meta[0];
                                upd_lo <= i_meta[0];
                                upd_hi_val <= i_meta[0] ? 32'b0 : ri_val;
                                upd_lo_val <= i_meta[0] ? ri_val : 32'b0;
                            end
                            3'd5: begin // MULDIV
                                commit <= 1;
                                commit_upd <= 0;
                                muldiv_clear <= 1;  // 释放乘除法器
                                upd_hi <= 1;
                                upd_lo <= 1;
                                upd_hi_val <= muldiv_res[63:32];
                                upd_lo_val <= muldiv_res[31:0];
                            end
                            3'd6: begin // CP0
                                // TLBR, TLBP, TLBWR, TLBWI, MTC0, MFC0
                                if (is_kernel) begin
                                    cp0_ce <= 1;
                                    if (i_uop == 13 || i_uop == 14) begin   // MTC0, MFC0
                                        commit <= 0;
                                        status <= STATUS_CP0_0;
                                        cp0_inst <= (i_uop == 14) ? 0 : 1;
                                        cp0_param <= i_meta[4:0];
                                        cp0_putval <= ri_val;
                                    end
                                    else begin
                                        commit <= 1;
                                        commit_upd <= 0;
                                        cp0_inst <= i_uop - 6'd6; // 2~5    TLBR, TLBP, TLBWR, TLBWI
                                    end
                                end
                                else begin  // 非内核态使用CP0将触发保护异常
                                    commit <= 0;
                                    excode <= 5'h0a;      // RI
                                    normal_exc <= 1;
                                end
                            end
                            3'd7: begin // ERET
                                commit <= 0;
                                status <= STATUS_ERET_0;
                                cp0_ce <= 1;
                                cp0_inst <= 1;  // MFC0
                                cp0_param <= 5'd14; // EPC
                            end
                        endcase
                    end
                end
                else if (i_status == STATUS_MEM0) begin // 在其他过程中均不处理中断
                    if (i_excode) begin // 地址异常
                        // 会触发clear导致
                        normal_exc <= 1;
                    end
                    else if (mem_tlbmiss) begin
                        tlb_exc <= 1;
                        mem_vaddr <= sl_addr;
                        if (i_uop == 6'd0 || i_uop == 6'd1 || i_uop == 6'd2 ) begin
                            excode <= 5'h03;
                        end
                        else begin
                            excode <= 5'h02;
                        end
                    end
                    else if (mem_modify_ex) begin
                        normal_exc <= 1;
                        excode <= 5'h01;
                    end
                    else begin
                        status <= STATUS_MEM1;
                    end
                end
                else if (i_status == STATUS_MEM1) begin
                    if (mem_avail) begin   
                        if (i_uop == 6'd0 || i_uop == 6'd1 || i_uop == 6'd2 ) begin
                            // Store
                            commit <= 1;
                            commit_upd <= i_result_reg;
                            commit_reg <= i_result_reg_id;
                            commit_regheap <= i_result_regheap;
                        end
                        else begin
                            // Load
                            status <= STATUS_FORCE_COMMIT;
                            force_upd <= 1;
                            force_upd_val <= mem_read_data;
                        end
                    end
                    else begin
                        status <= STATUS_MEM1;
                    end
                end
                else if (i_status == STATUS_CP0_0) begin
                    status <= STATUS_CP0_1;
                end
                else if (i_status == STATUS_CP0_1) begin
                    
                    if (i_result_reg) begin
                        force_upd <= 1;
                        force_upd_val <= cp0_result;
                        status <= STATUS_FORCE_COMMIT;
                    end
                    else begin
                        commit <= 1;
                        commit_upd <= i_result_reg;
                        commit_reg <= i_result_reg_id;
                        commit_regheap <= i_result_regheap;
                    end
                end
                else if (i_status == STATUS_ERET_0) begin
                    status <= STATUS_ERET_1;
                end
                else if (i_status == STATUS_ERET_1) begin
                    cp0_ce <= 1;
                    if (cp0_result[1:0] == 2'b00) begin
                        commit <= 1;
                        commit_upd <= 0;
                        change_pc_imm <= 1; // 立即修改PC
                        change_pc_to <= cp0_result;
                        cp0_inst <= 3'd6;   // ERET
                    end
                    else begin
                        cp0_ce <= 0;
                        commit <= 0;     // 不提交
                        excode <= 5'h04;      // AdEL
                        normal_exc <= 1;
                        mem_vaddr <= cp0_result;
                    end
                end
                else if (i_status == STATUS_FORCE_COMMIT) begin
                    commit <= 1;
                    commit_upd <= i_result_reg;
                    commit_reg <= i_result_reg_id;
                    commit_regheap <= i_result_regheap;
                end
            end
        
        end
    end
end

endmodule

