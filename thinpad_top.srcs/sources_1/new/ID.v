module ID(
    input wire clk,
    input wire rst,

    input wire[31:0] ins,
    
    input wire reg_write,
    input wire[4:0] write_reg,
    input wire[31:0] write_data,
    
    output reg if_reg_write,
    output reg if_mem_read,
    output reg if_mem_write,
    output reg[5:0] op,
    output reg[5:0] func,
    
    output reg[31:0] data_a,
    output reg[31:0] data_b,
    output reg[4:0] data_write_reg,
    output reg[31:0] simm,
    output reg[31:0] zimm,
    output reg[25:0] jpc,
    
    // pass
    input wire[31:0] npc_i,
    output reg[31:0] npc_o
    );

(* DONT_TOUCH = "yes" *) reg[31:0] registers[0:31];

// ID
always@(*) begin
    npc_o <= npc_i;
    
    op <= ins[31:26];
    func <= ins[5:0];
    jpc <= ins[25:0];
    
    data_a <= (reg_write && (write_reg == ins[25:21])) ? write_data : registers[ins[25:21]];
    data_b <= (reg_write && (write_reg == ins[20:16])) ? write_data : registers[ins[20:16]];
    
    // 符号扩展
    simm <= ins[15] ? {16'hffff, ins[15:0]} : {16'h0000, ins[15:0]};
    zimm <= {16'h0000, ins[15:0]};
    
    // avoid latches
    data_write_reg <= 5'b00000;
    
    case (ins[31:26])
        // R型
        6'b000000, 6'b011100: begin
        // SPECAL (ADD, SUB, ..., JR, JALR)
        // SPECIAL2 (CLO CLZ)
            if_reg_write <= 1'b0; // 在旁路单元中写回
            if_mem_read <= 1'b0;
            if_mem_write <= 1'b0;
            data_write_reg <= ins[15:11];
        end
        
        6'b010000: begin
        // COP0
            if_reg_write <= 1'b0; // 在旁路单元中写回
            if_mem_read <= 1'b0;
            if_mem_write <= 1'b0;
            data_write_reg <= ins[20:16];
        end
        
        6'b001000, 6'b001001, 6'b001100, 6'b001101, 6'b001110, 6'b001111, 6'b001010, 6'b001011: begin
        // ADDI ADDIU ANDI ORI ORI LUI SLTI SLTIU
            if_reg_write <= 1'b0; // 在旁路单元中写回
            if_mem_read <= 1'b0;
            if_mem_write <= 1'b0;
            data_write_reg <= ins[20:16];
        end
        
        6'b100011, 6'b100001, 6'b100101, 6'b100000, 6'b100100: begin
        // LW LH LHU LB LBU
            if_reg_write <= 1'b1;
            if_mem_read <= 1'b1;
            if_mem_write <= 1'b0;
            data_write_reg <= ins[20:16];
        end
        
        6'b101011, 6'b101001, 6'b101000: begin
        // SW SH SB
            if_reg_write <= 1'b0;
            if_mem_read <= 1'b0;
            if_mem_write <= 1'b1;
        end
        
        6'b000011, 6'b000001: begin
        // JAL / BLTZ / BGEZ / BLTZAL / BGEZAL
            if_reg_write <= 1'b0; // 在旁路单元中写回
            if_mem_read <= 1'b0;
            if_mem_write <= 1'b0;
            data_write_reg <= 5'b11111;
        end
        
        default: begin
        // BEQ / BNE / BGTZ / BLEZ / J / unknown
            if_reg_write <= 1'b0;
            if_mem_read <= 1'b0;
            if_mem_write <= 1'b0;
        end
    endcase
end

// reg Write
always@(posedge clk or negedge rst) begin
    if (!rst) begin
        registers[0] <= 32'b0;
        registers[1] <= 32'b0;
        registers[2] <= 32'b0;
        registers[3] <= 32'b0;
        registers[4] <= 32'b0;
        registers[5] <= 32'b0;
        registers[6] <= 32'b0;
        registers[7] <= 32'b0;
        registers[8] <= 32'b0;
        registers[9] <= 32'b0;
        registers[10] <= 32'b0;
        registers[11] <= 32'b0;
        registers[12] <= 32'b0;
        registers[13] <= 32'b0;
        registers[14] <= 32'b0;
        registers[15] <= 32'b0;
        registers[16] <= 32'b0;
        registers[17] <= 32'b0;
        registers[18] <= 32'b0;
        registers[19] <= 32'b0;
        registers[20] <= 32'b0;
        registers[21] <= 32'b0;
        registers[22] <= 32'b0;
        registers[23] <= 32'b0;
        registers[24] <= 32'b0;
        registers[25] <= 32'b0;
        registers[26] <= 32'b0;
        registers[27] <= 32'b0;
        registers[28] <= 32'b0;
        registers[29] <= 32'b0;
        registers[30] <= 32'b0;
        registers[31] <= 32'b0;
    end
    else if (reg_write && (write_reg != 0)) begin
        registers[write_reg] <= write_data;
        registers[0] <= 32'b0;
    end
    else registers[0] <= 32'b0;
end

endmodule
