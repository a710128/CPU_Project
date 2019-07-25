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
    
    // TLB ²éÑ¯ /  IF
    input wire          tlb_qe1,
    input wire[31:0]    vaddr1,
    input wire[7:0]     asid1,
    output wire[31:0]   paddr1,
    output wire         tlb_miss1,
    
    // TLB ²éÑ¯ /  Mem
    input wire          tlb_qe2,
    input wire          is_laod2,
    input wire[31:0]    vaddr2,
    input wire[7:0]     asid2,
    output wire[31:0]   paddr2,
    output wire         tlb_miss2,
    output wire         tlb_modified_ex,
    
    // TLBP
    input wire          tlbp_qe,
    input wire[31:0]    tlbp_hi,
    output reg[4:0]     tlbp_result,
    
    // TLBR
    input wire          tlbr_qe,
    input wire[3:0]     tlbr_index,
    output reg[95:0]    tlbr_result,
    
    // TLB ĞŞ¸Ä
    input wire tlb_we,
    input wire[3:0] tlb_write_index,
    input wire[95:0] tlb_write_entry    // { EntryHi, EntryLo0, EntryLo1 }
);

parameter TLB_SIZE = 16; 
wire[19:0] if_tlb_results[TLB_SIZE - 1: 0];
wire[TLB_SIZE - 1: 0] if_tlb_miss;

assign paddr1[11:0] = vaddr1[11:0];

tlb_selector #(20) if_tlb_selector(
    .inp0(if_tlb_results[0]),
    .inp1(if_tlb_results[1]),
    .inp2(if_tlb_results[2]),
    .inp3(if_tlb_results[3]),
    .inp4(if_tlb_results[4]),
    .inp5(if_tlb_results[5]),
    .inp6(if_tlb_results[6]),
    .inp7(if_tlb_results[7]),
    .inp8(if_tlb_results[8]),
    .inp9(if_tlb_results[9]),
    .inp10(if_tlb_results[10]),
    .inp11(if_tlb_results[11]),
    .inp12(if_tlb_results[12]),
    .inp13(if_tlb_results[13]),
    .inp14(if_tlb_results[14]),
    .inp15(if_tlb_results[15]),
    
    .sel(if_tlb_miss),
    
    .miss(tlb_miss1),
    .result(paddr1[31:12])
);

wire[20:0] mem_tlb_results[TLB_SIZE - 1: 0];
wire[TLB_SIZE - 1: 0] mem_tlb_miss;
wire[20:0]  mem_tlb_select_result;

assign paddr2[11:0] = vaddr2[11:0];
assign paddr2[31:12] = mem_tlb_select_result[19:0];
assign tlb_modified_ex = (~mem_tlb_select_result[20]) & is_laod2;   // Load && !Dirty

tlb_selector #(21) mem_tlb_selector(
    .inp0(mem_tlb_results[0]),
    .inp1(mem_tlb_results[1]),
    .inp2(mem_tlb_results[2]),
    .inp3(mem_tlb_results[3]),
    .inp4(mem_tlb_results[4]),
    .inp5(mem_tlb_results[5]),
    .inp6(mem_tlb_results[6]),
    .inp7(mem_tlb_results[7]),
    .inp8(mem_tlb_results[8]),
    .inp9(mem_tlb_results[9]),
    .inp10(mem_tlb_results[10]),
    .inp11(mem_tlb_results[11]),
    .inp12(mem_tlb_results[12]),
    .inp13(mem_tlb_results[13]),
    .inp14(mem_tlb_results[14]),
    .inp15(mem_tlb_results[15]),
    
    .sel(mem_tlb_miss),
    
    .miss(tlb_miss2),
    .result(mem_tlb_select_result)
);


wire[TLB_SIZE - 1 : 0] tlbp_match;
wire[95:0] tlbr_entry[TLB_SIZE - 1 : 0];

always @(*) begin
    if (tlbp_qe) begin
        tlbp_result <= 5'd16;   // Not Found
        if (tlbp_match[0])  tlbp_result <= 5'd0;
        if (tlbp_match[1])  tlbp_result <= 5'd1;
        if (tlbp_match[2])  tlbp_result <= 5'd2;
        if (tlbp_match[3])  tlbp_result <= 5'd3;
        if (tlbp_match[4])  tlbp_result <= 5'd4;
        if (tlbp_match[5])  tlbp_result <= 5'd5;
        if (tlbp_match[6])  tlbp_result <= 5'd6;
        if (tlbp_match[7])  tlbp_result <= 5'd7;
        if (tlbp_match[8])  tlbp_result <= 5'd8;
        if (tlbp_match[9])  tlbp_result <= 5'd9;
        if (tlbp_match[10])  tlbp_result <= 5'd10;
        if (tlbp_match[11])  tlbp_result <= 5'd11;
        if (tlbp_match[12])  tlbp_result <= 5'd12;
        if (tlbp_match[13])  tlbp_result <= 5'd13;
        if (tlbp_match[14])  tlbp_result <= 5'd14;
        if (tlbp_match[15])  tlbp_result <= 5'd15;
    end
    else begin
        tlbp_result <= 5'd16;   // Not Found
    end
end

always @(*) begin
    if (tlbr_qe) begin
        tlbr_result <= tlbr_entry[tlbr_index];
    end
    else begin
        tlbr_result <= 0;
    end
end


// Generate Entries
generate
    genvar i;
    for (i = 0; i < TLB_SIZE; i = i + 1)
    begin:TLB_ENTRY_LABEL
        tlb_entry tlb_entry_inst (
            .clk(clk),
            .rst(rst),
            
            // IF
            .ce1(tlb_qe1),
            .vaddr1(vaddr1[31:12]),
            .asid1(asid1),
            .paddr1(if_tlb_results[i]),
            .miss1(if_tlb_miss[i]),
            
            // MEM
            .ce2(tlb_qe2),
            .vaddr2(vaddr2[31:12]),
            .asid2(asid2),
            .paddr2(mem_tlb_results[i][19:0]),
            .miss2(mem_tlb_miss[i]),
            .dirty(mem_tlb_results[i][20]),
            
            // TLBP
            .tlbp_qe(tlbp_qe),
            .tlbp_hi(tlbp_hi),
            .tlbp_match(tlbp_match[i]),
            
            // TLBR
            .tlbr_entry(tlbr_entry[i]),
            
            // TLB Write
            .tlb_we(tlb_we && (tlb_write_index == i)),
            .tlb_write_entry(tlb_write_entry)
        );
    end
endgenerate


endmodule
