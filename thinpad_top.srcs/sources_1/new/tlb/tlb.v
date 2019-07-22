`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/21 15:06:14
// Design Name: 
// Module Name: tlb_lv2
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


module tlb(
    input wire clk,
    input wire rst,
    
    // TLB ²éÑ¯ / from IF
    input wire tlb_qe1,
    input wire[31:0] vaddr1,
    input wire[7:0] asid1,
    output reg[31:0] paddr1,
    output wire tlb_miss1,
    
    // TLB ²éÑ¯ / from Mem
    input wire          tlb_qe2,
    input wire          is_laod2,
    input wire[31:0]    vaddr2,
    input wire[7:0]     asid2,
    output reg[31:0]    paddr2,
    output wire         tlb_miss2,
    output reg          tlb_modified_ex,
    
    // TLBP
    input wire          tlbp_qe,
    input wire[31:0]    tlbp_hi,
    output wire[3:0]    tlbp_result,
    
    // TLBR
    input wire          tlbr_qe,
    input wire[3:0]     tlbr_index,
    output wire[95:0]   tlbr_result,
    
    // TLB ÐÞ¸Ä
    input wire tlb_we,
    input wire[3:0] tlb_write_index,
    input wire[95:0] tlb_write_entry
);




endmodule
