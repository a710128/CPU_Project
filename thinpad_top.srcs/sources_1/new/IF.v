`define pc im_addr

module IF(
    input wire clk,
    input wire rst,
    
    input wire[31:0] jpc,
    input wire if_pc_jump,
    
    input wire if_bubble,
    // for exception
    // jpc = npc - 4
    
    input wire[31:0] im_data,
    output reg[31:0] im_addr,
    
    output reg[31:0] npc = 32'hBFC00000, // pc_inital
    output reg[31:0] ins
    );

reg[31:0] data_hold;
reg if_data_hold;
parameter IM_ADDR_INIT = 32'hBFC00000;

// ∂¡»°÷∏¡Ó
always @(*) begin
    ins <= if_data_hold ? data_hold : im_data;
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        npc <= IM_ADDR_INIT;
        `pc <= IM_ADDR_INIT - 32'd4;
        if_data_hold <= 1'b0;
    end
    else if (!if_bubble) begin
        if (if_pc_jump) begin
            `pc <= jpc;
            npc <= jpc + 32'd4;
            if_data_hold <= 1'b0;
        end
        else begin
            `pc <= npc;
            npc <= npc + 32'd4;
            if_data_hold <= 1'b0;
        end
    end
    else begin
        if_data_hold <= 1'b1;
    end
    data_hold <= ins;
end

endmodule
