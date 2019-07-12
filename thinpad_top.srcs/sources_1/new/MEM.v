    module MEM(
    input wire mem_read,
    input wire mem_write,
    
    output reg mem_read_o,
    
    // pass
    input wire if_reg_write_i,
    output reg if_reg_write_o,
    input wire[31:0] ex_res_i,
    output reg[31:0] ex_res_o,
    input wire[4:0] data_write_reg_i,
    output reg[4:0] data_write_reg_o
    );

always @(*) begin
    mem_read_o <= mem_read;
    if_reg_write_o <= if_reg_write_i;
    ex_res_o <= ex_res_i;
    data_write_reg_o <= data_write_reg_i;
end

endmodule
