`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/22 19:00:35
// Design Name: 
// Module Name: mmu
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


module mmu(
    input wire clk,
    input wire rst,
    
    // Global
    input wire[31:0]     current_entryHi,
    
    // IF
    input wire          if_qe,
    input wire[31:0]    if_vaddr,
    output reg[31:0]    if_paddr,
    output reg          if_miss,
    
    // Mem
    input wire          mem_qe,
    input wire          mem_is_load,
    input wire[31:0]    mem_vaddr,
    output reg[31:0]    mem_paddr,
    output reg[1:0]     mem_tlb_exception,
    
    // TLBP
    input wire          tlbp_qe,
    output reg[4:0]     tlbp_result,
    
    // TLBR
    input wire          tlbr_qe,
    input wire[3:0]     tlbr_index,
    output reg[95:0]    tlbr_result,
    
    // TLB ĞŞ¸Ä
    input wire          tlb_we,
    input wire[3:0]     tlb_write_index,
    input wire[95:0]    tlb_write_entry    // { EntryHi, EntryLo0, EntryLo1 }
);

reg         tlb_qe1;
reg[31:0]   tlb_result1;
reg         tlb_miss1;

always @(*) begin
    if (if_qe) begin
        if ((if_vaddr >= 32'h80000000) && (if_vaddr < 32'hC0000000)) begin
            if_paddr <= {3'b0, if_vaddr[28:0]};
            tlb_qe1 <= 0;
            if_miss <= 0;
        end
        else begin
            tlb_qe1 <= 1;
            if_paddr <= tlb_result1;
            if_miss <= tlb_miss1;
        end
    end
    else begin
        if_paddr <= 32'b0;
        tlb_qe1 <= 0;
        if_miss <= 0;
    end
end


reg         tlb_qe2;
reg[31:0]   tlb_result2;
reg[1:0]    tlb_exception; // {dirty, miss}

always @(*) begin
    if (mem_qe) begin
        if ((mem_vaddr >= 32'h80000000) && (mem_vaddr < 32'hC0000000)) begin
            mem_paddr <= {3'b0, mem_vaddr[28:0]};
            tlb_qe2 <= 0;
            mem_tlb_exception <= 0;
        end
        else begin
            tlb_qe2 <= 1;
            mem_paddr <= tlb_result2;
            
            if (tlb_exception[0]) begin  // Miss
                mem_tlb_exception <= mem_is_load ? 2 : 3;
            end
            else if(tlb_exception[1]) begin // Modified Exception
                mem_tlb_exception <= 1;
            end
            else begin
                mem_tlb_exception <= 0;
            end
            
        end
    end
    else begin
        mem_paddr <= 32'b0;
        tlb_qe2 <= 0;
        mem_tlb_exception <= 0;
    end
end

tlb tlb_inst (
    .clk(clk),
    .rst(rst),
    
    .tlb_qe1(tlb_qe1),
    .vaddr1(if_vaddr),
    .asid1(current_entryHi[7:0]),
    .paddr1(tlb_result1),
    .tlb_miss1(tlb_miss1),
    
    .tlb_qe2(tlb_qe2),
    .is_laod2(mem_is_load),
    .vaddr2(mem_vaddr),
    .asid2(current_entryHi[7:0]),
    .paddr2(tlb_result2),
    .tlb_miss2(tlb_exception[0]),
    .tlb_modified_ex(tlb_exception[1]),
    
    .tlbp_qe(tlbp_qe),
    .tlbp_hi(current_entryHi),
    .tlbp_result(tlbp_result),
    
    .tlbr_qe(tlbr_qe),
    .tlbr_index(tlbr_index),
    .tlbr_result(tlbr_result),
    
    .tlb_we(tlb_we),
    .tlb_write_index(tlb_write_index),
    .tlb_write_entry(tlb_write_entry)
);


endmodule
