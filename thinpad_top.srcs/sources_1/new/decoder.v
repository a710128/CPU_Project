`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/24 15:37:41
// Design Name: 
// Module Name: decoder
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


module decoder(
    input wire          clk,
    input wire          period0,
    input wire          rst,
    input wire          clear,              // 清空流水线以及当前指令
    
    // 指令输入
    input wire[31:0]    inst,
    input wire          if_tlbmiss,
    input wire[31:0]    pc,
    input wire          noinst,
    input wire[31:0]    pred_jump,          // 分支预测跳转地址
    
    // 指令提交（更新寄存器状态）
    input wire          buffer_shift,
    input wire          commit,
    input wire[4:0]     commit_reg,
    input wire[5:0]     commit_regheap,
    
    // 发射指令
    output reg          cant_issue,         // 运算器资源不足
    output reg          issue,
    output reg [2:0]    issue_buffer_id,
    output reg [4:0]    issue_reg,          // 发射指令的真实寄存器编号
    output reg          assign_reg,
    output reg [5:0]    assign_reg_id,      // 关联寄存器编号
    output reg          assign_component,   
    output reg [2:0]    assign_component_id,    //  0~5:    ALU,    6:  BRANCH,     7: MULDIV
    output reg          issue_ri,
    output reg [5:0]    issue_ri_id,
    output reg          issue_rj,
    output reg [5:0]    issue_rj_id,
    output reg [2:0]    issue_commit_op, //   0: nothing,   1: branch,      2:  mem     3.  MFHI/LO,    4.  MTHI/LO,   5. Copy From MULDIV,     6.  CP0 inst in uop,    7. ERET
    output reg [4:0]    issue_excode,
    output reg [5:0]    issue_uop,
    output reg [31:0]   issue_meta, // Immediate 或其他信息
    output reg [31:0]   issue_pc,
    output reg [31:0]   issue_j,    // 分支预测跳转你地址
    output reg          issue_delay_slot,   // 是否延迟槽指令
    
    // 状态获取
    input wire[63:0]    regheap_status,     // r0~r55
    input wire[5:0]     alu_status,
    input wire          branch_status,
    input wire          muldiv_status,
    input wire[7:0]     buffer_status       // Reorder buffer 使用状态
);

wire[7:0]   next_buffer_status;     // 下个周期开始时的使用状态（若commit则位移否则不变）
assign next_buffer_status = buffer_shift ? {1'b0, buffer_status[7:1]} : buffer_status;

reg[5:0]    reg_commit[31:0];
reg[5:0]    reg_active[31:0];

wire[5:0]   unused_reg;     // 任意可用寄存器堆编号
reg[2:0]    unused_alu;     // 任意可用ALU
reg[2:0]    unused_buffer;  // 最靠前的一个未使用的rob
wire        any_alu, any_branch, any_muldiv, any_buffer;


assign      any_alu = ~ (alu_status[0] & alu_status[1] & alu_status[2] & alu_status[3] & alu_status[4] & alu_status[5]);
assign      any_branch = ~ branch_status;
assign      any_muldiv = ~ muldiv_status;
assign      any_buffer = ~ (next_buffer_status[0] & next_buffer_status[1] & next_buffer_status[2] & next_buffer_status[3] &
                            next_buffer_status[4] & next_buffer_status[5] & next_buffer_status[6] & next_buffer_status[7]);

always @(*) begin
    if (any_alu) begin
        if (!alu_status[0]) unused_alu <= 0;
        if (!alu_status[1]) unused_alu <= 1;
        if (!alu_status[2]) unused_alu <= 2;
        if (!alu_status[3]) unused_alu <= 3;
        if (!alu_status[4]) unused_alu <= 4;
        if (!alu_status[5]) unused_alu <= 5;
    end
end

always @(*) begin
    if (any_buffer) begin
        case(next_buffer_status)
        8'b00000000: unused_buffer <= 0;
        8'b00000001: unused_buffer <= 1;
        8'b00000011: unused_buffer <= 2;
        8'b00000111: unused_buffer <= 3;
        8'b00001111: unused_buffer <= 4;
        8'b00011111: unused_buffer <= 5;
        8'b00111111: unused_buffer <= 6;
        default unused_buffer <= 7;
        endcase
    end
end


wire[5:0]   op = inst[31:26];
wire[5:0]   func = inst[5:0];
wire[4:0]   mt = inst[25:21];
wire[31:0]  simm = inst[15] ? {16'hffff, inst[15:0]} : {16'h0000, inst[15:0]};
wire[31:0]  zimm ={16'h0000, inst[15:0]};

/* ======================= Instructions ===================== */
// special
wire        is_add      =   (op == 6'b000000) && (func == 6'b100000) && (inst[10:6] == 5'b00000);
wire        is_addu     =   (op == 6'b000000) && (func == 6'b100001) && (inst[10:6] == 5'b00000);
wire        is_sub      =   (op == 6'b000000) && (func == 6'b100010) && (inst[10:6] == 5'b00000);
wire        is_subu     =   (op == 6'b000000) && (func == 6'b100011) && (inst[10:6] == 5'b00000);
wire        is_and      =   (op == 6'b000000) && (func == 6'b100100) && (inst[10:6] == 5'b00000);
wire        is_or       =   (op == 6'b000000) && (func == 6'b100101) && (inst[10:6] == 5'b00000);
wire        is_xor      =   (op == 6'b000000) && (func == 6'b100110) && (inst[10:6] == 5'b00000);
wire        is_nor      =   (op == 6'b000000) && (func == 6'b100111) && (inst[10:6] == 5'b00000);
wire        is_sll      =   (op == 6'b000000) && (func == 6'b000000) && (inst[25:21] == 5'b00000);
wire        is_sllv     =   (op == 6'b000000) && (func == 6'b000100) && (inst[10:6] == 5'b00000);
wire        is_srl      =   (op == 6'b000000) && (func == 6'b000010) && (inst[25:21] == 5'b00000);
wire        is_srlv     =   (op == 6'b000000) && (func == 6'b000110) && (inst[10:6] == 5'b00000);
wire        is_sra      =   (op == 6'b000000) && (func == 6'b000011) && (inst[25:21] == 5'b00000);
wire        is_srav     =   (op == 6'b000000) && (func == 6'b000111) && (inst[10:6] == 5'b00000);
wire        is_slt      =   (op == 6'b000000) && (func == 6'b101010) && (inst[10:6] == 5'b00000);
wire        is_sltu     =   (op == 6'b000000) && (func == 6'b101011) && (inst[10:6] == 5'b00000);
wire        is_jr       =   (op == 6'b000000) && (func == 6'b001000) && (inst[20:11] == 5'b00000);
wire        is_jalr     =   (op == 6'b000000) && (func == 6'b001001) && (inst[20:16] == 5'b00000);
wire        is_mfhi     =   (op == 6'b000000) && (func == 6'b010000) && (inst[10:6] == 5'b00000) && (inst[25:16] == 10'b0);
wire        is_mflo     =   (op == 6'b000000) && (func == 6'b010010) && (inst[10:6] == 5'b00000) && (inst[25:16] == 10'b0);
wire        is_mtlo     =   (op == 6'b000000) && (func == 6'b010011) && (inst[20:6] == 15'b0);
wire        is_mthi     =   (op == 6'b000000) && (func == 6'b010001) && (inst[20:6] == 15'b0);
wire        is_syscall  =   (op == 6'b000000) && (func == 6'b001100);
wire        is_break    =   (op == 6'b000000) && (func == 6'b001101);
wire        is_movz     =   (op == 6'b000000) && (func == 6'b001010) && (inst[10:6] == 5'b00000);
wire        is_multu    =   (op == 6'b000000) && (func == 6'b011001) && (inst[15:6] == 10'b0);
wire        is_mult     =   (op == 6'b000000) && (func == 6'b011000) && (inst[15:6] == 10'b0);
wire        is_div      =   (op == 6'b000000) && (func == 6'b011010) && (inst[15:6] == 10'b0);
wire        is_divu     =   (op == 6'b000000) && (func == 6'b011011) && (inst[15:6] == 10'b0);

// COP0
wire        is_mtc0     =   (op == 6'b010000) && (mt == 5'b00100) && (inst[10:3] == 8'b0);
wire        is_mfc0     =   (op == 6'b010000) && (mt == 5'b00000) && (inst[10:3] == 8'b0);
wire        is_eret     =   (op == 6'b010000) && (mt == 5'b10000) && (func == 6'b011000) && (inst[20:6] == 15'b0);
wire        is_tlbwi    =   (op == 6'b010000) && (mt == 5'b10000) && (func == 6'b000010) && (inst[20:6] == 15'b0);
wire        is_tlbwr    =   (op == 6'b010000) && (mt == 5'b10000) && (func == 6'b000110) && (inst[20:6] == 15'b0);
wire        is_tlbp     =   (op == 6'b010000) && (mt == 5'b10000) && (func == 6'b001000) && (inst[20:6] == 15'b0);
wire        is_tlbr     =   (op == 6'b010000) && (mt == 5'b10000) && (func == 6'b000001) && (inst[20:6] == 15'b0);

// Immediate
wire        is_addi     =   (op == 6'b001000);
wire        is_addiu    =   (op == 6'b001001);
wire        is_andi     =   (op == 6'b001100);
wire        is_ori      =   (op == 6'b001101);
wire        is_xori     =   (op == 6'b001110);
wire        is_slti     =   (op == 6'b001010);
wire        is_sltiu    =   (op == 6'b001011);
wire        is_lui      =   (op == 6'b001111) && (inst[25:21] == 5'b00000);

// branch/jump
wire        is_j        =   (op == 6'b000010);
wire        is_jal      =   (op == 6'b000011);
wire        is_beq      =   (op == 6'b000100);
wire        is_bne      =   (op == 6'b000101);
wire        is_bgtz     =   (op == 6'b000111) && (inst[20:16] == 5'b00000);
wire        is_blez     =   (op == 6'b000110) && (inst[20:16] == 5'b00000);
// --- RegImm
wire        is_bltz     =   (op == 6'b000001) && (inst[20:16] == 5'b00000);
wire        is_bltzal   =   (op == 6'b000001) && (inst[20:16] == 5'b10000);
wire        is_bgez     =   (op == 6'b000001) && (inst[20:16] == 5'b00001);
wire        is_bgezal   =   (op == 6'b000001) && (inst[20:16] == 5'b10001);

wire        is_lw       =   (op == 6'b100011);
wire        is_lh       =   (op == 6'b100001);
wire        is_lhu      =   (op == 6'b100101);
wire        is_lb       =   (op == 6'b100000);
wire        is_lbu      =   (op == 6'b100100);
wire        is_sw       =   (op == 6'b101011);
wire        is_sh       =   (op == 6'b101001);
wire        is_sb       =   (op == 6'b101000);


wire        require_alu;
wire        require_branch;
wire        require_muldiv;
wire        require_nothing;

wire[5:0]   alu_opid;
wire[5:0]   branch_opid;
wire[2:0]   muldiv_opid;
wire[5:0]   other_opid;

convt64to6 convt64to6_alu (
    .inp({39'b0, is_add , is_addu , is_sub , is_subu , is_and , is_or , is_xor , is_nor , is_sll , 
         is_sllv , is_srl , is_srlv , is_sra , is_srav , is_slt , is_sltu , is_movz , is_addi , 
         is_addiu , is_andi , is_ori , is_xori , is_slti , is_sltiu , is_lui}), // total 25
    .out(alu_opid),
    .found(require_alu)
);

convt64to6 convt64to6_branch (
    .inp({52'b0, is_jr , is_jalr , is_j , is_jal , is_beq , is_bne , is_bgtz , is_blez ,  is_bltz , is_bltzal , is_bgez , is_bgezal}), // total 12
    .out(branch_opid),
    .found(require_branch)
);

convt8to3 convt8to3_muldiv (
    .inp({4'b0, is_divu, is_div, is_multu, is_mult }),    // total 4
    .out(muldiv_opid),
    .found(require_muldiv)
);

convt64to6 convt64to6_other (
    .inp({43'b0, is_mfhi , is_mflo , is_mtlo , is_mthi , is_syscall , is_break , is_mtc0 , is_mfc0 , 
        is_eret , is_tlbwi , is_tlbwr , is_tlbp , is_tlbr , is_lw , is_lh , is_lhu , is_lb ,
        is_lbu , is_sw , is_sh , is_sb}), // total 21
    .out(other_opid),
    .found(require_nothing)
);

convt64to6 convt64to6_unused_reg (
    .inp(~regheap_status),
    .out(unused_reg),
    .found()
);

reg last_branch;
reg last_cant_issue;

always @(posedge clk) begin
    if (rst) begin
        reg_commit[0] <= 0;
        reg_commit[1] <= 1;
        reg_commit[2] <= 2;
        reg_commit[3] <= 3;
        reg_commit[4] <= 4;
        reg_commit[5] <= 5;
        reg_commit[6] <= 6;
        reg_commit[7] <= 7;
        reg_commit[8] <= 8;
        reg_commit[9] <= 9;
        reg_commit[10] <= 10;
        reg_commit[11] <= 11;
        reg_commit[12] <= 12;
        reg_commit[13] <= 13;
        reg_commit[14] <= 14;
        reg_commit[15] <= 15;
        reg_commit[16] <= 16;
        reg_commit[17] <= 17;
        reg_commit[18] <= 18;
        reg_commit[19] <= 19;
        reg_commit[20] <= 20;
        reg_commit[21] <= 21;
        reg_commit[22] <= 22;
        reg_commit[23] <= 23;
        reg_commit[24] <= 24;
        reg_commit[25] <= 25;
        reg_commit[26] <= 26;
        reg_commit[27] <= 27;
        reg_commit[28] <= 28;
        reg_commit[29] <= 29;
        reg_commit[30] <= 30;
        reg_commit[31] <= 31;
        
        reg_active[0] <= 0;
        reg_active[1] <= 1;
        reg_active[2] <= 2;
        reg_active[3] <= 3;
        reg_active[4] <= 4;
        reg_active[5] <= 5;
        reg_active[6] <= 6;
        reg_active[7] <= 7;
        reg_active[8] <= 8;
        reg_active[9] <= 9;
        reg_active[10] <= 10;
        reg_active[11] <= 11;
        reg_active[12] <= 12;
        reg_active[13] <= 13;
        reg_active[14] <= 14;
        reg_active[15] <= 15;
        reg_active[16] <= 16;
        reg_active[17] <= 17;
        reg_active[18] <= 18;
        reg_active[19] <= 19;
        reg_active[20] <= 20;
        reg_active[21] <= 21;
        reg_active[22] <= 22;
        reg_active[23] <= 23;
        reg_active[24] <= 24;
        reg_active[25] <= 25;
        reg_active[26] <= 26;
        reg_active[27] <= 27;
        reg_active[28] <= 28;
        reg_active[29] <= 29;
        reg_active[30] <= 30;
        reg_active[31] <= 31;
        
        last_branch <= 0;
        last_cant_issue <= 0;
    end
    else if (clear) begin
        reg_active[0] <= reg_commit[0];
        reg_active[1] <= reg_commit[1];
        reg_active[2] <= reg_commit[2];
        reg_active[3] <= reg_commit[3];
        reg_active[4] <= reg_commit[4];
        reg_active[5] <= reg_commit[5];
        reg_active[6] <= reg_commit[6];
        reg_active[7] <= reg_commit[7];
        reg_active[8] <= reg_commit[8];
        reg_active[9] <= reg_commit[9];
        reg_active[10] <= reg_commit[10];
        reg_active[11] <= reg_commit[11];
        reg_active[12] <= reg_commit[12];
        reg_active[13] <= reg_commit[13];
        reg_active[14] <= reg_commit[14];
        reg_active[15] <= reg_commit[15];
        reg_active[16] <= reg_commit[16];
        reg_active[17] <= reg_commit[17];
        reg_active[18] <= reg_commit[18];
        reg_active[19] <= reg_commit[19];
        reg_active[20] <= reg_commit[20];
        reg_active[21] <= reg_commit[21];
        reg_active[22] <= reg_commit[22];
        reg_active[23] <= reg_commit[23];
        reg_active[24] <= reg_commit[24];
        reg_active[25] <= reg_commit[25];
        reg_active[26] <= reg_commit[26];
        reg_active[27] <= reg_commit[27];
        reg_active[28] <= reg_commit[28];
        reg_active[29] <= reg_commit[29];
        reg_active[30] <= reg_commit[30];
        reg_active[31] <= reg_commit[31];
        last_branch <= 0;
        last_cant_issue <= 0;
        
        if (commit) begin // commit 同时 clear
            reg_commit[commit_reg] <= commit_regheap;
            reg_active[commit_reg] <= commit_regheap;
        end
    end
    else begin
        // 默认情况
        if (issue) begin
            last_branch <= require_branch;
        end
    
        if (commit) begin
            reg_commit[commit_reg] <= commit_regheap;
        end
        
        if (assign_reg) begin
            reg_active[issue_reg] <=  assign_reg_id;
        end
        
        last_cant_issue <= cant_issue;
    end
    
    
end


always @(*) begin
    cant_issue <= 0;
    issue <= 0;
    issue_buffer_id <= 0;
    issue_reg <= 0;  
    assign_reg <= 0;
    assign_reg_id <= 0;
    assign_component <= 0;
    assign_component_id <= 0;
    issue_ri <= 0;
    issue_ri_id <= 0;
    issue_rj <= 0;
    issue_rj_id <= 0;
    issue_commit_op <= 0;
    issue_excode <= 0;
    issue_uop <= 0;
    issue_meta <= 0;
    issue_pc <= 0;
    issue_j <= 0;
    issue_delay_slot <= 0;
    
    if (rst || clear || !period0) begin
        // 如果 rst 或者 clear 则不进行操作
        cant_issue <= last_cant_issue;
    end
    else if (noinst) begin       // 没有指令
        cant_issue <= 0;    // 可以发射
        issue <= 0;         // 不发射
        assign_reg <= 0;
        assign_component <= 0;
    end
    else begin              // 有指令，需要发射
        if (!any_buffer) begin  // 没有rob
            cant_issue <= 1;
            issue <= 0;
            assign_reg <= 0;
            assign_component <= 0;
        end
        else begin              // 有rob 
            issue_buffer_id <= unused_buffer;
            issue_pc <= pc;
            issue_j <= pred_jump;
            issue_delay_slot <= last_branch;
            
            if (if_tlbmiss) begin       // IF TLB miss
                cant_issue <= 0;
                issue <= 1;
                assign_reg <= 0;                // 不需要回写寄存器
                assign_component <= 0;          // 不需要运算元件
                issue_ri <= reg_commit[0];      // 0寄存器
                issue_rj <= reg_commit[0];      // 0寄存器
                issue_commit_op <= 0;           // 无特殊指令
                issue_excode <= 2;              // TLBL Exception
                issue_uop <= 0;
                issue_meta <= 0;
            end
            else if (require_alu) begin // ALU
                if (any_alu) begin
                    // 可以发射
                    cant_issue <= 0;
                    issue <= 1;
                    assign_reg <= 1;    // 需要关联回写寄存器
                    assign_reg_id <= unused_reg;
                    assign_component <= 1;  // 需要关联运算单元
                    assign_component_id <= unused_alu;
                    issue_commit_op <=  0;  // 无特殊指令
                    issue_excode <= 0;
                    issue_uop <= alu_opid;
                    issue_ri_id <= 0;
                    issue_rj_id <= 0;
                    
                    case (alu_opid)
                        6'd0: begin // LUI
                            issue_reg <= inst[20:16];
                            issue_ri <= 0;
                            issue_rj <= 0;
                            issue_meta <= zimm;
                        end
                        6'd1, 6'd2: begin // SLTIU, STLI
                            issue_reg <= inst[20:16];
                            issue_ri <= 1;
                            issue_ri_id <= reg_active[inst[25:21]];
                            issue_rj <= 0;
                            issue_meta <= simm;
                        end
                        6'd3, 6'd4, 6'd5: begin // XORI, ori
                            issue_reg <= inst[20:16];
                            issue_ri <= 1;
                            issue_ri_id <= reg_active[inst[25:21]];
                            issue_rj <= 0;
                            issue_meta <= zimm;
                        end
                        6'd6, 6'd7: begin   // ADDIU, ADDI
                            issue_reg <= inst[20:16];
                            issue_ri <= 1;
                            issue_ri_id <= reg_active[inst[25:21]];
                            issue_rj <= 0;
                            issue_meta <= simm;
                        end
                        6'd8, 6'd9, 6'd10, 6'd11, 6'd12, 6'd13, 6'd14, 6'd15,   // MOVZ, SLTU, SLT, SRAV, SRA, SRLV, SRL, SLLV
                        6'd16, 6'd17, 6'd18, 6'd19, 6'd20, 6'd21, 6'd22, 6'd23, 6'd24 : begin  // SLL, NOR, XOR, OR, AND, SUBU, SUB, ADDU, ADD
                            issue_reg <= inst[15:11];
                            issue_ri <= 1;
                            issue_ri_id <= reg_active[inst[25:21]];
                            issue_rj <= 1;
                            issue_rj_id <= reg_active[inst[20:16]];
                            issue_meta <= {27'b0, inst[10:6]};
                        end
                        default: ;
                    endcase
                end
                else begin
                    // 无法发射
                    cant_issue <= 1;
                    issue <= 0;
                    assign_reg <= 0;
                    assign_component <= 0;
                end
            end
            else if (require_branch) begin // BRANCH
                if (any_branch) begin
                    cant_issue <= 0;
                    issue <= 1;
                    assign_component <= 1;
                    assign_component_id <= 6;
                    issue_commit_op <= 1;   // 处理分支跳转情况/更新分支预测表
                    issue_excode <= 0;
                    issue_uop <= branch_opid;
                    
                    case(branch_opid)
                    6'd0, 6'd2: begin     // BGEZAL, BLTZAL
                        issue_reg <= 31;
                        assign_reg <= 1;
                        assign_reg_id <= unused_reg;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[25:21]];
                        issue_rj <= 0;
                        issue_meta <= simm;
                    end
                    6'd1, 6'd3, 6'd4, 6'd5: begin     // BGEZ, BLTZ, BLEZ, BGTZ
                        assign_reg <= 0;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[25:21]];
                        issue_rj <= 0;
                        issue_meta <= simm;
                    end
                    6'd6, 6'd7: begin // BNE, BEQ
                        assign_reg <= 0;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[25:21]];
                        issue_rj <= 1;
                        issue_rj_id <= reg_active[inst[20:16]];
                        issue_meta <= simm;
                    end
                    6'd8: begin // JAL
                        issue_reg <= 31;
                        assign_reg <= 1;
                        assign_reg_id <= unused_reg;
                        issue_ri <= 0;
                        issue_rj <= 0;
                        issue_meta <= {6'b0, inst[25:0]};
                    end
                    6'd9: begin // J
                        assign_reg <= 0;
                        issue_ri <= 0;
                        issue_rj <= 0;
                        issue_meta <= {6'b0, inst[25:0]};
                    end
                    6'd10: begin // JALR
                        issue_reg <= inst[15:11];
                        assign_reg <= 1;
                        assign_reg_id <= unused_reg;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[25:21]];
                        issue_rj <= 0;
                        issue_meta <= 32'b0;
                    end
                    6'd11: begin // JR
                        assign_reg <= 0;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[25:21]];
                        issue_rj <= 0;
                        issue_meta <= 32'b0;
                    end
                    default: ;
                    endcase
                end
                else begin
                    // 无法发射
                    cant_issue <= 1;
                    issue <= 0;
                    assign_reg <= 0;
                    assign_component <= 0;
                end
            end
            else if (require_muldiv) begin
                if (any_muldiv) begin
                    cant_issue <= 0;
                    issue <= 1;
                    assign_reg <= 0;            // 不回写寄存器
                    assign_component <= 1;
                    assign_component_id <= 7;   // MULDIV
                    issue_commit_op <= 5;       // Copy From MULDIV
                    issue_excode <= 0;
                    issue_meta <= 0;            // 乘除法均无立即数


                    issue_uop <= muldiv_opid;
                    issue_ri <= 1;
                    issue_rj <= 1;
                    issue_ri_id <= reg_active[inst[25:21]]; // rs
                    issue_rj_id <= reg_active[inst[20:16]]; // rt
                end
                else begin
                    // 无法发射
                    cant_issue <= 1;
                    issue <= 0;
                    assign_reg <= 0;
                    assign_component <= 0;
                end
            end
            else if (require_nothing) begin 
                // 一定可以发射
                cant_issue <= 0;
                issue <= 1;
                assign_component <= 0;          // 不需要运算元件，使用特殊通路回写
                issue_uop <= other_opid;
                case(other_opid)
                    6'd0, 6'd1, 6'd2: begin // SB, SH, SW
                        assign_reg <= 0;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[25:21]];
                        issue_rj <= 1;
                        issue_rj_id <= reg_active[inst[20:16]];
                        issue_commit_op <= 2;   // MEM
                        issue_excode <= 0;
                        issue_meta <= simm;
                    end
                    6'd3, 6'd4, 6'd5, 6'd6, 6'd7: begin // LBU, LB, LHU, LH, LW
                        assign_reg <= 1;
                        issue_reg <= inst[20:16];
                        assign_reg_id <= unused_reg;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[25:21]];
                        issue_rj <= 0;
                        issue_commit_op <= 2;   // MEM
                        issue_excode <= 0;
                        issue_meta <= simm;
                    end
                    6'd8, 6'd9, 6'd10, 6'd11: begin // TLBR, TLBP, TLBWR, TLBWI
                        assign_reg <= 0;
                        issue_ri <= 0;
                        issue_rj <= 0;
                        issue_commit_op <= 6;   // CP0
                        issue_excode <= 0;
                    end
                    6'd12: begin    // ERET
                        assign_reg <= 0;
                        issue_ri <= 0;
                        issue_rj <= 0;
                        issue_commit_op <= 7;   // ERET
                        issue_excode <= 0;
                    end
                    6'd13: begin    // MFC0
                        assign_reg <= 1;
                        issue_reg <= inst[20:16];
                        assign_reg_id <= unused_reg;
                        issue_ri <= 0;
                        issue_rj <= 0;
                        issue_commit_op <= 6;   // CP0
                        issue_excode <= 0;
                        issue_meta <= {27'b0, inst[15:11]};
                    end
                    6'd14: begin    // MTC0
                        assign_reg <= 0;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[20:16]];
                        issue_rj <= 0;
                        issue_commit_op <= 6;   // CP0
                        issue_excode <= 0;
                        issue_meta <= {27'b0, inst[15:11]};
                    end
                    6'd15: begin    // BREAK
                        assign_reg <= 0;
                        issue_ri <= 0;
                        issue_rj <= 0;
                        issue_commit_op <= 0;   //  nothing
                        issue_excode <= 5'h09;
                    end
                    6'd16: begin    // SYSCALL
                        assign_reg <= 0;
                        issue_ri <= 0;
                        issue_rj <= 0;
                        issue_commit_op <= 0;   // nothing
                        issue_excode <= 5'h08;
                    end
                    6'd17: begin    // MTHI
                        assign_reg <= 0;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[25:21]]; 
                        issue_rj <= 0;
                        issue_commit_op <= 4;   // MFHI/LO
                        issue_excode <= 0;
                        issue_meta <= 0;
                    end
                    6'd18: begin    // MTLO
                        assign_reg <= 0;
                        issue_ri <= 1;
                        issue_ri_id <= reg_active[inst[25:21]]; 
                        issue_rj <= 0;
                        issue_commit_op <= 4;   // MFHI/LO
                        issue_excode <= 0;
                        issue_meta <= 1;
                    end
                    6'd19: begin    // MFLO
                        assign_reg <= 1;
                        issue_reg <= inst[15:11];
                        assign_reg_id <= unused_reg;
                        issue_ri <= 0;
                        issue_rj <= 0;
                        issue_commit_op <= 3;   // MTHI/LO
                        issue_excode <= 0;
                        issue_meta <= 1;
                    end
                    6'd20: begin    // MFHI
                        assign_reg <= 1;
                        issue_reg <= inst[15:11];
                        assign_reg_id <= unused_reg;
                        issue_ri <= 0;
                        issue_rj <= 0;
                        issue_commit_op <= 3;   // MTHI/LO
                        issue_excode <= 0;
                        issue_meta <= 0;
                    end
                    default: ;
                endcase
            end
            else begin  // Reserved (illegal) Instruction
                cant_issue <= 0;
                issue <= 1;
                assign_reg <= 0;
                assign_component <= 0;
                issue_ri <= 0;
                issue_rj <= 0;
                issue_commit_op <= 0;
                issue_excode <= 5'h0a;  // Exception RI
                issue_uop <= 0;
                issue_meta <= 0;
            end
        end
    end
end

endmodule


module convt64to6(
    input wire[63:0]    inp,
    output reg [5:0]    out,
    output reg          found
);

wire[7:0]       subfd;
wire[2:0]       subot[7:0];

generate
    genvar i;
    for (i = 0; i < 8; i = i + 1)
    begin: CVT
        convt8to3 convt8to3_inst (
            .inp(inp[i * 8 + 7: i * 8]),
            .out(subot[i]),
            .found(subfd[i])
        );
    end
endgenerate

always @(*) begin
    found <= 1;
    if (subfd[0])  out <= {3'd0, subot[0]};
    else if (subfd[1])  out <= {3'd1, subot[1]};
    else if (subfd[2])  out <= {3'd2, subot[2]};
    else if (subfd[3])  out <= {3'd3, subot[3]};
    else if (subfd[4])  out <= {3'd4, subot[4]};
    else if (subfd[5])  out <= {3'd5, subot[5]};
    else if (subfd[6])  out <= {3'd6, subot[6]};
    else if (subfd[7])  out <= {3'd7, subot[7]};
    else found <= 0;
end


endmodule

module convt8to3(
    input wire[7:0]    inp,
    output reg[2:0]    out,
    output reg         found
);

always @(*) begin
    found <= 1;
    if (inp[0])  out <= 3'd0;
    else if (inp[1])  out <= 3'd1;
    else if (inp[2])  out <= 3'd2;
    else if (inp[3])  out <= 3'd3;
    else if (inp[4])  out <= 3'd4;
    else if (inp[5])  out <= 3'd5;
    else if (inp[6])  out <= 3'd6;
    else if (inp[7])  out <= 3'd7;
    else found <= 0; 
end

endmodule