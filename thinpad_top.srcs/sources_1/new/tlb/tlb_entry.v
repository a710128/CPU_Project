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
    
    // IF
    input wire          ce1,
    input wire[19:0]    vaddr1,
    input wire[7:0]     asid1,
    output reg[19:0]    paddr1,
    output reg          miss1,
    
    // MEM
    input wire          ce2,
    input wire[19:0]    vaddr2,
    input wire[7:0]     asid2,
    output reg[19:0]    paddr2,
    output reg          miss2,
    output reg          dirty,
    
    
    // TLBP
    input wire          tlbp_qe,
    input wire[31:0]    tlbp_hi,
    output reg          tlbp_match,
    
    // TLBR
    output wire[95:0]   tlbr_entry,
    
    // TLB ÐÞ¸Ä
    input wire          tlb_we,
    input wire[95:0]    tlb_write_entry
);
reg[95:0] entry;
reg bit_G;
wire[7:0] asid;
assign tlbr_entry = entry;
assign asid = entry[71:64];

always @(*) begin
    if (ce1) begin
        if (vaddr1[19:1] == entry[95:77] && ( (asid1 ==  asid) || bit_G )) begin
            paddr1 <= (vaddr1[0] == 0) ? entry[57:38] : entry[25:6];
            miss1 <= (vaddr1[0] == 0) ? ~entry[33] : ~entry[1];
        end
        else begin
            paddr1 <= 0;
            miss1 <= 1;
        end
    end
    else begin
        paddr1 <= 0;
        miss1 <= 0;
    end
end

always @(*) begin
    if (ce2) begin
        if (vaddr2[19:1] == entry[95:77] && ( (asid2 ==  asid) || bit_G )) begin
            paddr2 <= (vaddr2[0] == 0) ? entry[57:38] : entry[25:6];
            miss2 <= (vaddr2[0] == 0) ? ~entry[33] : ~entry[1];
            dirty <= (vaddr2[0] == 0) ? entry[34] : entry[2];
        end
        else begin
            paddr2 <= 0;
            miss2 <= 1;
            dirty <= 1;
        end
    end
    else begin
        paddr2 <= 0;
        miss2 <= 0;
        dirty <= 1;
    end
end

always @(*) begin
    if (tlbp_qe) begin
        if (tlbp_hi[31:13] == entry[95:77] && ( (tlbp_hi[7:0] ==  asid) || bit_G )) tlbp_match <= entry[33] & entry[1];
        else tlbp_match <= 0;
    end
    else begin
        tlbp_match <= 0;
    end
end

always @(posedge clk or negedge rst) begin
    if (rst) begin
        entry <= 0;
        bit_G <= 0;
    end
    else if (tlb_we) begin
        entry <= tlb_write_entry;
        bit_G <= (tlb_write_entry[33] == 1) ? tlb_write_entry[32] : tlb_write_entry[0]; // Lo0.Valid ? Lo0.G : Lo1.G
    end
end

endmodule
