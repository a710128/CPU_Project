`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/21 15:34:41
// Design Name: 
// Module Name: tlb_entry
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


module tlb_entry(
    input wire clk,
    input wire rst,
    
    input wire          ce1,
    input wire[31:0]    vaddr1,
    input wire[31:0]    asid1,
    output reg[31:0]    paddr1,
    output reg          miss1,
    
    
    input wire          ce2,
    input wire[31:0]    vaddr2,
    input wire[31:0]    asid2,
    output reg[31:0]    paddr2,
    output reg          miss2,
    
    input wire          ce3,
    input wire[31:0]    vaddr3,
    input wire[31:0]    asid3,
    output reg[31:0]    paddr3,
    output reg          miss3
);
endmodule
