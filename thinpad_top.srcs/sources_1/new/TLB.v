`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/11 11:55:47
// Design Name: 
// Module Name: TLB
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


module TLB(
    input wire clk,
    input wire rst,
    
    input wire tlb_query,
    input wire[19:0] tlb_query_vpn,
    
    input wire tlb_write,
    input wire[3:0] tlb_index,
    input wire[95:0] tlb_entry,
    
    input wire[7:0] current_asid,
    
    output reg[25:0] tlb_pfn,
    output reg tlb_miss,
    
    // TLBP. TLBR
    input wire tlbp_query,
    input wire tlbr_query,
    output reg[4:0] tlb_query_idx,
    output reg[95:0] tlb_query_entry
);
parameter TLB_SIZE = 16; 

wire[25:0] pfns[TLB_SIZE - 1: 0];
wire[TLB_SIZE - 1: 0] entry_miss;


wire[TLB_SIZE - 1: 0] tlbp_match;
wire[95:0] tlb_entries[TLB_SIZE - 1: 0];
generate
    genvar i;
    for (i = 0; i < TLB_SIZE; i = i + 1)
    begin:TLB_ENTRY_LABEL
        TLB_ENTRY tlb_entry_inst (
            .clk(clk),
            .rst(rst),
            
            .ce(tlb_query),
            .addr(tlb_query_vpn),
            .write(tlb_write && (tlb_index == i)),
            .wrt_entry(tlb_entry),
            .pfn(pfns[i]),
            .miss(entry_miss[i]),
            
            .current_asid(current_asid),
            
            .tlbp_query(tlbp_query),
            .tlbp_match(tlbp_match[i]),
            .tlb_query_entry(tlb_entries[i])
        );
    end
endgenerate


wire[25:0] pfns_lv1[3:0];
wire[3:0] miss_lv1;

generate
    for (i = 0; i < 4; i = i + 1)
    begin: TLB_SELECTOR_LV0
        ENTRY_SELECTOR selector_lv0 (
            .inp0(pfns[i * 4 + 0]),
            .inp1(pfns[i * 4 + 1]),
            .inp2(pfns[i * 4 + 2]),
            .inp3(pfns[i * 4 + 3]),
            .sel(entry_miss[i * 4 + 3: i * 4]),
            
            .oup(pfns_lv1[i]),
            .miss(miss_lv1[i])
        );
    end
endgenerate

wire[25:0] final_pfn;
wire final_miss;

ENTRY_SELECTOR selector_lv1 (
    .inp0(pfns_lv1[0]),
    .inp1(pfns_lv1[1]),
    .inp2(pfns_lv1[2]),
    .inp3(pfns_lv1[3]),
    .sel(miss_lv1),
    
    .oup(final_pfn),
    .miss(final_miss)
);

always @(*) begin
    if (tlb_query) begin
        tlb_pfn <= final_pfn;
        tlb_miss <= final_miss;
    end
    else begin
        tlb_pfn <= 26'b0;
        tlb_miss <= 0;
    end
end

always @(*) begin
    if (tlbp_query) begin
        tlb_query_idx <= 5'd16;
        if (tlbp_match[15]) tlb_query_idx <= 5'd15;
        if (tlbp_match[14]) tlb_query_idx <= 5'd14;
        if (tlbp_match[13]) tlb_query_idx <= 5'd13;
        if (tlbp_match[12]) tlb_query_idx <= 5'd12;
        if (tlbp_match[11]) tlb_query_idx <= 5'd11;
        if (tlbp_match[10]) tlb_query_idx <= 5'd10;
        if (tlbp_match[09]) tlb_query_idx <= 5'd9;
        if (tlbp_match[08]) tlb_query_idx <= 5'd8;
        if (tlbp_match[07]) tlb_query_idx <= 5'd7;
        if (tlbp_match[06]) tlb_query_idx <= 5'd6;
        if (tlbp_match[05]) tlb_query_idx <= 5'd5;
        if (tlbp_match[04]) tlb_query_idx <= 5'd4;
        if (tlbp_match[03]) tlb_query_idx <= 5'd3;
        if (tlbp_match[02]) tlb_query_idx <= 5'd2;
        if (tlbp_match[01]) tlb_query_idx <= 5'd1;
        if (tlbp_match[00]) tlb_query_idx <= 5'd0;
    end
    else tlb_query_idx <= 5'd16;
end

always @(*) begin
    if (tlbr_query) begin
        tlb_query_entry <= tlb_entries[tlb_index];
    end
end


endmodule

/*
    SELECTOR
*/

module ENTRY_SELECTOR (
    input wire[25:0]    inp0,
    input wire[25:0]    inp1,
    input wire[25:0]    inp2,
    input wire[25:0]    inp3,
    input wire[3:0]     sel,
    
    output reg[25:0]   oup,
    output reg         miss
);

always @(*) begin
    if (~sel[0]) begin
        oup <= inp0;
        miss <= 0;
    end
    else if (~sel[1]) begin
        oup <= inp1;
        miss <= 0;
    end
    else if (~sel[2]) begin
        oup <= inp2;
        miss <= 0;
    end
    else if (~sel[3]) begin
        oup <= inp3;
        miss <= 0;
    end
    else begin
        miss <= 1;
    end
end

endmodule