`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/21 15:32:50
// Design Name: 
// Module Name: tlb_selector
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


module tlb_selector #(parameter WIDTH = 33) (
    input wire[WIDTH - 1 : 0]    inp0,
    input wire[WIDTH - 1 : 0]    inp1,
    input wire[WIDTH - 1 : 0]    inp2,
    input wire[WIDTH - 1 : 0]    inp3,
    input wire[WIDTH - 1 : 0]    inp4,
    input wire[WIDTH - 1 : 0]    inp5,
    input wire[WIDTH - 1 : 0]    inp6,
    input wire[WIDTH - 1 : 0]    inp7,
    input wire[WIDTH - 1 : 0]    inp8,
    input wire[WIDTH - 1 : 0]    inp9,
    input wire[WIDTH - 1 : 0]    inp10,
    input wire[WIDTH - 1 : 0]    inp11,
    input wire[WIDTH - 1 : 0]    inp12,
    input wire[WIDTH - 1 : 0]    inp13,
    input wire[WIDTH - 1 : 0]    inp14,
    input wire[WIDTH - 1 : 0]    inp15,
    
    input wire[15:0]    sel,
    
    output wire         miss,
    output wire[WIDTH - 1 : 0]   result
);

wire[3:0] miss4;
wire[WIDTH - 1:0]  result4[3:0];

tlb_selector_4 #(WIDTH) s0 (
    .inp0(inp0),
    .inp1(inp1),
    .inp2(inp2),
    .inp3(inp3),
    .sel(sel[3:0]),
    .miss(miss4[0]),
    .result(result4[0])
);

tlb_selector_4 #(WIDTH) s1 (
    .inp0(inp4),
    .inp1(inp5),
    .inp2(inp6),
    .inp3(inp7),
    .sel(sel[7:4]),
    .miss(miss4[1]),
    .result(result4[1])
);

tlb_selector_4 #(WIDTH) s2 (
    .inp0(inp8),
    .inp1(inp9),
    .inp2(inp10),
    .inp3(inp11),
    .sel(sel[11:8]),
    .miss(miss4[2]),
    .result(result4[2])
);

tlb_selector_4 #(WIDTH) s3 (
    .inp0(inp12),
    .inp1(inp13),
    .inp2(inp14),
    .inp3(inp15),
    .sel(sel[15:12]),
    .miss(miss4[3]),
    .result(result4[3])
);

tlb_selector_4 #(WIDTH) s4 (
    .inp0(result4[0]),
    .inp1(result4[1]),
    .inp2(result4[2]),
    .inp3(result4[3]),
    .sel(miss4),
    .miss(miss),
    .result(result)
);

endmodule

module tlb_selector_4 #(parameter WIDTH = 33) (
    input wire[WIDTH - 1 : 0]    inp0,
    input wire[WIDTH - 1 : 0]    inp1,
    input wire[WIDTH - 1 : 0]    inp2,
    input wire[WIDTH - 1 : 0]    inp3,
    
    input wire[3:0]    sel,
    
    output reg         miss,
    output reg[WIDTH - 1 : 0]   result
);

always @(*) begin
    if (sel[0] == 0) begin
        miss <= 0;
        result <= inp0;
    end
    else if (sel[1] == 0) begin
        miss <= 0;
        result <= inp1;
    end
    else if (sel[2] == 0) begin
        miss <= 0;
        result <= inp2;
    end
    else if (sel[3] == 0) begin
        miss <= 0;
        result <= inp3;
    end
    else begin
        miss <= 1;
        result <= 0;
    end
end


endmodule