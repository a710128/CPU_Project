//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/11 13:54:31
// Design Name: 
// Module Name: TLB_ENTRY
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


module TLB_ENTRY(
    input wire clk,
    input wire rst,
    
    input wire      ce,
    input wire[19:0] addr,
    
    input wire write,
    input wire[95:0] wrt_entry,
    
    input wire[7:0] current_asid,
    
    output reg[25:0] pfn,
    output reg miss,
    
    input wire tlbp_query,
    output reg tlbp_match,
    output reg[95:0] tlb_query_entry
);

reg[31:0] Hi, L0, L1;

wire is_glob;
assign is_glob = L0[1] ? L0[0] : L1[0];

always @(*) begin
    if (ce) begin
        if (addr[19:1] == Hi[31:13] && ((Hi[7:0] == current_asid) || is_glob)) begin
            pfn <= (addr[0] == 0) ? L0[31:6] : L1[31:6]; 
            miss <= (addr[0] == 0) ? !L0[1] : !L1[1];     // Valid
        end
        else begin
            pfn <= 26'b0;
            miss <= 1;
        end
    end
    else begin
        pfn <= 26'b0;
        miss <= 0;
    end
end

always @(*) begin
    tlb_query_entry <= {Hi, L0, L1};
end

always @(*) begin
    if (tlbp_query) begin
        tlbp_match <= (wrt_entry[95:77] == Hi[31:13] && ((wrt_entry[71:64] == Hi[7:0]) || is_glob)); // VPN && (asid || G)
    end
    else begin
        tlbp_match <= 1'b0;
    end
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        Hi <= 32'b0;
        L0 <= 32'b0;
        L1 <= 32'b0;
    end
    else if (write) begin
        Hi <= wrt_entry[95:64];
        L0 <= wrt_entry[63:32];
        L1 <= wrt_entry[31:0];
    end
end

endmodule
