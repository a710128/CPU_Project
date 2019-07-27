`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/25 20:04:33
// Design Name: 
// Module Name: cp0
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


module cp0(
    input wire          clk,
    input wire          rst,
    
    output wire[31:0]   cp0_entryhi,
    output wire[31:0]   cp0_ebase,
    output wire[31:0]   cp0_status,
    output wire[31:0]   cp0_counter,
    output wire[31:0]   cp0_compare,
    
    input  wire         cp0_ce,
    input  wire[2:0]    cp0_inst,
    input  wire[4:0]    cp0_reg,
    input  wire[31:0]   cp0_putval,
    output reg [31:0]   cp0_result,
    
    input  wire         cp0_exception,
    input  wire[4:0]    cp0_excode,
    input  wire[31:0]   cp0_exc_pc,
    input  wire[31:0]   cp0_mem_vaddr,
    input  wire         cp0_exc_ds,
    
    // Interrupt
    input  wire[5:0]    ip_7_2,
    
    // TLBR
    output wire         tlbr_qe,
    output reg[3:0]     tlbr_index,
    input wire[95:0]    tlbr_result,
    
    // TLBP
    output wire         tlbp_qe,
    input  wire[4:0]    tlbp_result,
    
    // TLB ÐÞ¸Ä
    output wire         tlb_we,
    output reg[3:0]     tlb_write_index,
    output reg[95:0]    tlb_write_entry    // { EntryHi, EntryLo0, EntryLo1 }
);

parameter INDEX = 0;        // Index
parameter RANDOM = 1;       // Random
parameter ENTRYL0 = 2;      // EntryLo0
parameter ENTRYL1 = 3;      // EntryLo1
parameter PAGEMASK = 5;     // PageMask
parameter BVA = 8;          // BadVAddr
parameter COUNT = 9;        // Counter
parameter ENTRYHI = 10;     // EntryHi
parameter COMPARE = 11;     // Compare
parameter STATUS = 12;      // SR
parameter CAUSE = 13;       // Cause
parameter EPC = 14;         // EPC
parameter EBASE = 15;         // ExceptionBase


(* KEEP = "TRUE" *) reg[31:0]   cp0_regs[31:0];
wire[31:0]  cp0[31:0];
reg         tlbp, tlbr, tlbwe;
reg[31:0]   random_reg;

assign tlbr_qe = tlbr;
assign tlbp_qe = tlbp;
assign tlb_we = tlbwe;

assign cp0[0] = cp0_regs[0];
assign cp0[1] = random_reg;     // RANDOM
assign cp0[2] = cp0_regs[2];
assign cp0[3] = cp0_regs[3];
assign cp0[4] = cp0_regs[4];
assign cp0[5] = cp0_regs[5];
assign cp0[6] = cp0_regs[6];
assign cp0[7] = cp0_regs[7];
assign cp0[8] = cp0_regs[8];
assign cp0[9] = cp0_regs[9];
assign cp0[10] = cp0_regs[10];
assign cp0[11] = cp0_regs[11];
assign cp0[12] = cp0_regs[12];
assign cp0[13] = {cp0_regs[13][31:16], ip_7_2, cp0_regs[13][9:0]};  // Cause
assign cp0[14] = cp0_regs[14];
assign cp0[15] = cp0_regs[15];  // EBASE
assign cp0[16] = cp0_regs[16];
assign cp0[17] = cp0_regs[17];
assign cp0[18] = cp0_regs[18];
assign cp0[19] = cp0_regs[19];
assign cp0[20] = cp0_regs[20];
assign cp0[21] = cp0_regs[21];
assign cp0[22] = cp0_regs[22];
assign cp0[23] = cp0_regs[23];
assign cp0[24] = cp0_regs[24];
assign cp0[25] = cp0_regs[25];
assign cp0[26] = cp0_regs[26];
assign cp0[27] = cp0_regs[27];
assign cp0[28] = cp0_regs[28];
assign cp0[29] = cp0_regs[29];
assign cp0[30] = cp0_regs[30];
assign cp0[31] = cp0_regs[31];

assign cp0_status = cp0[STATUS];
assign cp0_ebase = cp0[EBASE];
assign cp0_entryhi = cp0[ENTRYHI];
assign cp0_counter = cp0[COUNT];
assign cp0_compare = cp0[COMPARE];


always @(posedge clk) begin
    if (rst) begin
        cp0_regs[0] <= 0;
        cp0_regs[1] <= 0;
        cp0_regs[2] <= 0;
        cp0_regs[3] <= 0;
        cp0_regs[4] <= 0;
        cp0_regs[5] <= 0;
        cp0_regs[6] <= 0;
        cp0_regs[7] <= 0;
        cp0_regs[8] <= 0;
        cp0_regs[9] <= 0;
        cp0_regs[10] <= 0;
        cp0_regs[11] <= 0;
        cp0_regs[12] <= 0;  // SR
        cp0_regs[13] <= 0;
        cp0_regs[14] <= 0;
        cp0_regs[15] <= 32'h80001000;  // EBASE
        cp0_regs[16] <= 0;
        cp0_regs[17] <= 0;
        cp0_regs[18] <= 0;
        cp0_regs[19] <= 0;
        cp0_regs[20] <= 0;
        cp0_regs[21] <= 0;
        cp0_regs[22] <= 0;
        cp0_regs[23] <= 0;
        cp0_regs[24] <= 0;
        cp0_regs[25] <= 0;
        cp0_regs[26] <= 0;
        cp0_regs[27] <= 0;
        cp0_regs[28] <= 0;
        cp0_regs[29] <= 0;
        cp0_regs[30] <= 0;
        cp0_regs[31] <= 0;
    end
    else begin
        
        random_reg <= {28'b0,  random_reg[3:0] + 4'b1 };
        
        tlbp <= 0;
        tlbr <= 0;
        tlbwe <= 0;
        
        if (cp0[COUNT] < cp0[COMPARE]) begin
            cp0_regs[COUNT] <= cp0_regs[COUNT] + 1;
        end
        
        if (cp0_ce) begin
            case (cp0_inst)
                3'd0: begin // MTC0
                    cp0_regs[cp0_reg] <= cp0_putval;
                end
                3'd1: begin // MFC0
                    cp0_result <= cp0[cp0_reg];
                end
                3'd2: begin // TLBR
                    tlbr <= 1;
                    tlbr_index <= cp0[cp0[INDEX][3:0]];
                end
                3'd3: begin // TLBP
                    tlbp <= 1;
                end
                3'd4: begin // TLBWR
                    tlbwe <= 1;
                    tlb_write_index <= cp0[RANDOM][3:0];
                    tlb_write_entry <= { cp0[ENTRYHI], cp0[ENTRYL0], cp0[ENTRYL1] };
                end
                3'd5: begin // TLBWI
                    tlbwe <= 1;
                    tlb_write_index <= cp0[INDEX][3:0];
                    tlb_write_entry <= { cp0[ENTRYHI], cp0[ENTRYL0], cp0[ENTRYL1] };
                end
                3'd6: begin // ERET
                    cp0_regs[STATUS][1] <= 1'b0;
                end
                default: ;
            endcase
        end
        
        if (tlbr) begin
            cp0_regs[ENTRYHI] <= tlbr_result[95:64];
            cp0_regs[ENTRYL0] <= tlbr_result[63:32];
            cp0_regs[ENTRYL1] <= tlbr_result[31: 0];
        end
        
        if (tlbp) begin
            cp0_regs[INDEX] <= { tlbp_result[4], 27'b0, tlbp_result[3:0] };
        end
        
        if (cp0_exception) begin
            cp0_regs[CAUSE][6:2] <= cp0_excode;
            if (cp0[STATUS][1] == 1'b0) begin
                cp0_regs[CAUSE][31] <= cp0_exc_ds;
                cp0_regs[STATUS][1] <= 1'b1;
                cp0_regs[EPC] <= cp0_exc_ds ? (cp0_exc_pc - 32'd4) : cp0_exc_pc;
            end
            if (cp0_excode == 1 || cp0_excode == 2 || cp0_excode == 3 || cp0_excode == 4 || cp0_excode == 5) begin
                cp0_regs[BVA] <= cp0_mem_vaddr;
            end
        end
    end
end


endmodule
