`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/25 13:48:41
// Design Name: 
// Module Name: exe_top
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


module exe_top(
    input wire          clk,
    input wire          rst,
    
    input wire          issue,
    input wire[2:0]     issue_buffer_id,
    input wire[140:0]   issue_vec,
    
    output wire         buffer_shift,
    output wire         commit,
    output wire[4:0]    commit_reg,
    output wire[5:0]    commit_regheap,
    
    output wire[63:0]   regheap_status,
    output wire[7:0]    component_status,
    output wire[7:0]    buffer_status,
    
    output wire         mem_ce,
    output wire         mem_write,
    output wire[31:0]   mem_vaddr,
    output wire[4:0]    mem_bytemode,
    output wire[31:0]   mem_write_data,
    input  wire[31:0]   mem_read_data,
    input  wire         mem_avail,
    input  wire         mem_tlbmiss,
    input  wire         mem_modify_ex,      
    
    input  wire[5:0]    hardint,
    
    // cp0
    output wire         cp0_ce,
    output wire[2:0]    cp0_inst,
    output wire[4:0]    cp0_reg,
    output wire[31:0]   cp0_putval,
    output wire         cp0_exception,
    output wire[4:0]    cp0_excode,
    output wire[31:0]   cp0_exc_pc,
    output wire[31:0]   cp0_mem_vaddr,
    output wire         cp0_exc_ds,
    input  wire[31:0]   cp0_result,
    input  wire[31:0]   cp0_EBASE,
    input  wire[31:0]   cp0_SR,
    
    // jump forward
    output wire         clear_out,
    output reg          pc_jump,
    output reg[31:0]    pc_jump_addr,
    
    
    // feed bp
    output wire         feed_bp,
    output wire[31:0]   feed_bp_pc,
    output wire[31:0]   feed_bp_dst
);


wire        issue_assign_reg;
wire        issue_component;
wire[4:0]   issue_reg;
wire[5:0]   issue_regheap;
wire[2:0]   issue_component_id;

assign issue_assign_reg = issue_vec[0];
assign issue_component = issue_vec[12];
assign issue_reg = issue_vec[5:1];
assign issue_regheap = issue_vec[11:6];
assign issue_component_id = issue_vec[15:13];


wire[5:0]   commit_buffer_regid;        // 处于提交阶段的指令的回写寄存器编号
wire        commit_buffer_upd;          // 提交阶段指令是否需要更新寄存器
wire[31:0]  commit_buffer_val;          // 更新的值

reg         clear;
assign clear_out = clear;
wire        component_status_avail[7:0];
wire        component_change_meta[7:0];
wire        component_status_exc[7:0];
wire[31:0]  component_val[7:0];
wire[31:0]  component_nw_meta[7:0];
wire[4:0]   component_excode[7:0];

wire        buffer_commit;
wire        buffer_commit_upd;

assign buffer_shift = buffer_commit;
assign commit = buffer_commit & buffer_commit_upd;

// Generate Reg Heap

wire[2:0]   regheap_comp_id[63:0];
wire[63:0]  regheap_used, regheap_avail;
wire[31:0]  regheap_val[63:0];
assign regheap_status = regheap_used;


generate
    genvar i;
    for (i = 0; i < 64; i = i + 1)
    begin:REG_HEAP_GEN
        regheap_entry regheap_entry_inst (
            .clk(clk),
            .rst(rst),
            .clear(clear),
            .reg_id(i),
            
            .set_reg_a( issue && issue_assign_reg && (issue_regheap == i) ),
            .set_reg_R( issue_reg ),
            .set_commit_wb( ~issue_component ),
            .set_component_id( issue_component_id ),
            
            .reg_component_id ( regheap_comp_id[i] ),
            .reg_component_available( component_status_avail[ regheap_comp_id[i] ] ),
            .reg_component_val( component_val[ regheap_comp_id[i] ] ),
            
            .reg_used(regheap_used[i]),
            .reg_available(regheap_avail[i]),
            .reg_val(regheap_val[i]),
            
            .force_update((commit_buffer_regid == i) && commit_buffer_upd), // 在提交阶段且需要修改
            .force_value(commit_buffer_val),
            
            .commit(commit),
            .commit_regid(commit_reg),
            .commit_regheap(commit_regheap)
        );
    end
endgenerate

/* ========== REG HI/LO ========== */
reg[31:0] reg_HI, reg_LO;
wire upd_hi, upd_lo;
wire[31:0] upd_hi_val, upd_lo_val;

always @(posedge clk) begin
    if (rst) begin
        reg_HI <= 0;
        reg_LO <= 0;
    end
    else begin
        if (upd_hi) begin
            reg_HI <= upd_hi_val; 
        end
        if (upd_lo) begin
            reg_LO <= upd_lo_val;
        end
    end
end




/* =========   ALU   =========*/

wire        req_ri[7:0];
wire        req_rj[7:0];
wire[5:0]   req_riid[7:0];
wire[5:0]   req_rjid[7:0];


generate
    for (i = 0; i <= 5; i = i + 1)
    begin:ALU_GEN
        alu alu_inst(
            .clk(clk),
            .rst(rst),
            .clear(clear),
            
            // 获取发射信息
            .issue(issue && (issue_vec[12] == 1'b1) && (issue_vec[15:13] == i)),    // Issue && Component && CompID = i
            .issue_vec(issue_vec),
            
            // 获取寄存器状态
            .ri_val(req_ri[i] ?  regheap_val[req_riid[i]] : 32'b0 ),
            .ri_avail(req_ri[i] ? regheap_avail[req_riid[i]] : 1'b1),
            .rj_val(req_rj[i] ?  regheap_val[req_rjid[i]] : 32'b0 ),
            .rj_avail(req_rj[i] ? regheap_avail[req_rjid[i]] : 1'b1),
            
            // 输出状态
            .used(component_status[i]),
            .ri(req_ri[i]),
            .rj(req_rj[i]),
            .ri_id(req_riid[i]),
            .rj_id(req_rjid[i]),
            
            // 输出结果
            .result(component_val[i]),
            .avail(component_status_avail[i]),
            .change_meta(component_change_meta[i]),    // disabled
            .set_nw_meta(component_nw_meta[i]),    // disalbed
            .exc(component_status_exc[i]),
            .excode(component_excode[i])
        );
    end
endgenerate

/* ============ BRANCH =========== */
branch branch_inst(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    
    // 获取发射信息
    .issue(issue && (issue_vec[12] == 1'b1) && (issue_vec[15:13] == 6)),    // Issue && Component && CompID = i
    .issue_vec(issue_vec),
    
    // 获取寄存器状态
    .ri_val(req_ri[6] ?  regheap_val[req_riid[6]] : 32'b0 ),
    .ri_avail(req_ri[6] ? regheap_avail[req_riid[6]] : 1'b1),
    .rj_val(req_rj[6] ?  regheap_val[req_rjid[6]] : 32'b0 ),
    .rj_avail(req_rj[6] ? regheap_avail[req_rjid[6]] : 1'b1),
    
    // 输出状态
    .used(component_status[6]),
    .ri(req_ri[6]),
    .rj(req_rj[6]),
    .ri_id(req_riid[6]),
    .rj_id(req_rjid[6]),
    
    // 输出结果
    .result(component_val[6]),
    .avail(component_status_avail[6]),
    .change_meta(component_change_meta[6]),    // disabled
    .set_nw_meta(component_nw_meta[6]),    // disalbed
    .exc(component_status_exc[6]),
    .excode(component_excode[6])
);

/* ============ MULDIV =========== */
wire[63:0]  muldiv_result;
wire        muldiv_clear;
muldiv muldiv_inst(
    .clk(clk),
    .rst(rst),
    .clear(clear),
    
    // 获取发射信息
    .issue(issue && (issue_vec[12] == 1'b1) && (issue_vec[15:13] == 7)),    // Issue && Component && CompID = i
    .issue_vec(issue_vec),
    
    // 获取寄存器状态
    .ri_val(req_ri[7] ?  regheap_val[req_riid[7]] : 32'b0 ),
    .ri_avail(req_ri[7] ? regheap_avail[req_riid[7]] : 1'b1),
    .rj_val(req_rj[7] ?  regheap_val[req_rjid[7]] : 32'b0 ),
    .rj_avail(req_rj[7] ? regheap_avail[req_rjid[7]] : 1'b1),
    
    // 输出状态
    .used(component_status[7]),
    .ri(req_ri[7]),
    .rj(req_rj[7]),
    .ri_id(req_riid[7]),
    .rj_id(req_rjid[7]),
    
    // 输出结果
    .result(component_val[7]),
    .avail(component_status_avail[7]),
    .change_meta(component_change_meta[7]),    // disabled
    .set_nw_meta(component_nw_meta[7]),    // disalbed
    .exc(component_status_exc[7]),
    .excode(component_excode[7]),
    
    .read_result(muldiv_clear),
    .muldiv_result(muldiv_result)
);

/* ============ ROB ============ */
wire[141:0] rob_inps[8:0];
// reg[141:0]  rob_inp_reg[7:0];
assign rob_inps[8] = 141'b0;
assign commit_buffer_regid = rob_inps[0][11:6];

assign buffer_status[7] =  rob_inps[7][141];
assign buffer_status[6] =  rob_inps[6][141];
assign buffer_status[5] =  rob_inps[5][141];
assign buffer_status[4] =  rob_inps[4][141];
assign buffer_status[3] =  rob_inps[3][141];
assign buffer_status[2] =  rob_inps[2][141];
assign buffer_status[1] =  rob_inps[1][141];
assign buffer_status[0] =  rob_inps[0][141];

generate
    for (i = 7; i > 0; i = i - 1)
    begin:REORDER_BUFFER_GEN
        wire[141:0]    inp = buffer_commit ? rob_inps[i + 1] : rob_inps[i]; // 位移
        rob_entry rob_entry_inst (
            .clk(clk),
            .rst(rst),
            .clear(clear),
            
            .issue( issue && (issue_buffer_id == i ) ),
            .issue_inp(issue_vec),
            .rob_inp( inp ),  
            
            .i_comp_cmeta( inp[12] ? component_change_meta[ inp[15:13] ] : 1'b0),
            .i_nw_meta( inp[12] ? component_nw_meta[ inp[15:13] ] : 32'b0 ),
            
            .i_comp_exception( inp[12] ? component_status_exc[ inp[15:13] ] : 1'b0),
            .i_nw_excode( inp[12] ? component_excode[ inp[15:13] ] : 5'b0 ),
            
            .rob_oup( rob_inps[i] )
        );
    end
endgenerate

wire[141:0] rob_commit_inp = buffer_commit ? rob_inps[1] : rob_inps[0];
wire        commit_buffer_reg = rob_commit_inp[0];
wire[5:0]   commit_buffer_reg_id = rob_commit_inp[11:6];
wire        commit_buffer_ri = rob_commit_inp[16];
wire[5:0]   commit_buffer_ri_id = rob_commit_inp[22:17];
wire        commit_buffer_rj = rob_commit_inp[23];
wire[5:0]   commit_buffer_rj_id = rob_commit_inp[29:24];

// output
wire[3:0]   commit_buffer_status;
wire        commit_buffer_tlb_exception;
wire        commit_buffer_normal_exception;

wire        commit_pc_imm;
wire        commit_pc_ds;
wire        commit_pc_addr;
wire        commit_feed_bp;
wire[31:0]  commit_bp_res;


reg         ds_pc;          // 在提交延迟槽时修改PC
reg[31:0]   ds_pc_addr;

rob_commit rob_commit_inst(
    // BASE
    .clk(clk),
    .rst(rst),
    .clear(clear),
    
    .issue(issue && (issue_buffer_id == 0)),
    
    .issue_inp(issue_vec),
    .rob_inp( rob_commit_inp ),
    
    .i_comp_avail( rob_commit_inp[12] ? component_status_avail[ rob_commit_inp[15:13] ] : 1'b1 ),
    .i_comp_cmeta( rob_commit_inp[12] ? component_change_meta[ rob_commit_inp[15:13] ] : 1'b0 ),
    .i_nw_meta( rob_commit_inp[12] ? component_nw_meta[ rob_commit_inp[15:13] ] : 32'b0 ),
    .i_comp_exception( rob_commit_inp[12] ? component_status_exc[ rob_commit_inp[15:13] ] : 1'b0 ),
    .i_nw_excode( rob_commit_inp[12] ? component_excode[ rob_commit_inp[15:13] ] : 5'b0 ),
    
    .rob_oup( rob_inps[0] ),
    
    // EXT
    .commit(buffer_commit),
    .commit_upd(buffer_commit_upd),             // commit 是否需要修改寄存器
    .commit_reg(commit_reg),
    .commit_regheap(commit_regheap),
    
    .result_avail( commit_buffer_reg ? regheap_avail[commit_buffer_reg_id] : 1'b1),           // 是否已经计算出结果
    .ri_val( commit_buffer_ri ? regheap_val[commit_buffer_ri_id] : 32'b0 ),
    .rj_val( commit_buffer_rj ? regheap_val[commit_buffer_rj_id] : 32'b0 ),        
    .i_status( buffer_commit ? 4'd0 : commit_buffer_status ),               // 状态
    .o_status( commit_buffer_status ),
    
    .intq( hardint != 6'b000000 ),                   // 是否有外部中断
    .tlb_exc( commit_buffer_tlb_exception ),
    .normal_exc( commit_buffer_normal_exception ),
    .cp0_SR ( cp0_SR ),
    
    // Branch
    .change_pc_imm( commit_pc_imm ),
    .change_pc_ds( commit_pc_ds ),           // 在下一个延迟槽时修改PC
    .change_pc_to( commit_pc_addr ),
    .feed_to_bp( commit_feed_bp ),             // 是否更新分支预测表
    .feed_bp_res( commit_bp_res ),            // 分支跳转目的地址
    
    // MEM
    .mem_ce( mem_ce ),                 // 需要访存
    .mem_write( mem_write ),              // 是否写访存
    .mem_vaddr( mem_vaddr ),              // 访存地址
    .mem_bytemode( mem_bytemode ),           // 字节模式
    .mem_write_data( mem_write_data ),         // 写出数据
    .mem_read_data( mem_read_data ),          // 读入数据
    .mem_avail( mem_avail ),              // 操作完成
    .mem_tlbmiss( mem_tlbmiss ),            // TLB Miss
    .mem_modify_ex( mem_modify_ex ),
    
    // HI LO
    .reg_hi(reg_HI),
    .reg_lo(reg_LO),
    .upd_hi(upd_hi),
    .upd_lo(upd_lo),
    .upd_hi_val(upd_hi_val),
    .upd_lo_val(upd_lo_val),
    
    // force update
    .force_upd( commit_buffer_upd ),
    .force_upd_val( commit_buffer_val ),
    
    // MUL DIV
    .muldiv_res( muldiv_result ),
    .muldiv_clear( muldiv_clear ),
    
    // CP0
    .cp0_ce( cp0_ce ),
    .cp0_inst( cp0_inst ),
    .cp0_param( cp0_reg ),
    .cp0_putval( cp0_putval ),
    .cp0_result( cp0_result )       
);

assign cp0_exception = commit_buffer_tlb_exception | commit_buffer_normal_exception;
assign cp0_excode = rob_inps[0][37:33];
assign cp0_exc_pc = rob_inps[0][107:76];
assign cp0_mem_vaddr = (rob_inps[0][32:30] == 3'b0) ? rob_inps[0][107:76] :  mem_vaddr;
assign cp0_exc_ds = rob_inps[0][140];

assign feed_bp = commit_feed_bp;
assign feed_bp_dst = commit_bp_res;
assign feed_bp_pc = rob_inps[0][107:76];


always @(*) begin
    if (commit_buffer_tlb_exception) begin
        clear <= 1;
        pc_jump <= 1;
        pc_jump_addr <= cp0_EBASE;
    end
    else if (commit_buffer_normal_exception) begin
        clear <= 1;
        pc_jump <= 1;
        pc_jump_addr <= cp0_EBASE + 32'h180;
    end
    else if (commit_pc_imm) begin
        clear <= 1;
        pc_jump <= 1;
        pc_jump_addr <= commit_pc_addr;
    end
    else if (buffer_commit && rob_inps[0][140] && ds_pc) begin
        clear <= 1;
        pc_jump <= 1;
        pc_jump_addr <= ds_pc_addr;
    end
    else if (commit_pc_ds) begin
        clear <= 0;
        pc_jump <= 0;
    end
    else begin
        pc_jump <= 0;
        clear <= 0;
    end
end

always @(posedge clk) begin
    if (commit_buffer_tlb_exception) begin
        ds_pc <= 0;
    end
    else if (commit_buffer_normal_exception) begin
        ds_pc <= 0;
    end
    else if (commit_pc_imm) begin
        ds_pc <= 0;
    end
    else if (buffer_commit && rob_inps[0][140] && ds_pc) begin
        ds_pc <= 0;
    end
    else if (commit_pc_ds) begin
        ds_pc <= 1;
        ds_pc_addr <= commit_pc_addr;
    end
    else begin
    end
end

endmodule
