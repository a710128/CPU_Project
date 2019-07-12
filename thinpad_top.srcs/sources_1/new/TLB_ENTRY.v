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
    
    input wire      ce,
    input wire[19:0] addr,
    
    input wire write,
    input wire[95:0] wrt_entry,
    
    output reg[25:0] pfn,
    output reg miss 
);

reg[31:0] Hi, L0, L1;

always @(*) begin
    if (ce) begin
        if (addr[19:1] == Hi[31:13]) begin
            pfn <= (addr[0] == 0) ? L0[31:6] : L1[31:6]; 
            miss <= (addr[0] == 0) ? ~L0[1] : ~L1[1];     // Valid
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

always @(posedge clk) begin
    if (write) begin
        Hi <= wrt_entry[95:64];
        L0 <= wrt_entry[63:32];
        L1 <= wrt_entry[31:0];
    end
end

endmodule
