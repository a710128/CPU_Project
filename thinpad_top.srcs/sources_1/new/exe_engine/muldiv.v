`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/26 02:31:08
// Design Name: 
// Module Name: muldiv
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


module muldiv(
    input wire      clk,
    input wire      rst,
    input wire      clear,
    
    // 获取发射信息
    input wire          issue,
    input wire[140:0]   issue_vec,
    
    // 获取寄存器状态
    input wire[31:0]    ri_val,
    input wire          ri_avail,
    input wire[31:0]    rj_val,
    input wire          rj_avail,
    
    // 输出状态
    output wire         used,
    output wire         ri,
    output wire         rj,
    output wire[5:0]    ri_id,
    output wire[5:0]    rj_id,
    
    // 输出结果
    output wire[31:0]   result,
    output wire         avail,
    output wire         change_meta,    // disabled
    output wire[31:0]   set_nw_meta,    // disalbed
    output wire         exc,
    output wire[4:0]    excode,
    
    input  wire         read_result,
    output wire[63:0]   muldiv_result
);

reg[3:0]        status;

reg             alu_ri, alu_rj;
reg[5:0]        alu_riid, alu_rjid;
reg[5:0]        alu_uop;
wire[63:0]      long_result[3:0];
wire[63:0]      div_result[3:2];


assign used = (status == 0) ? 1'b0 : 1'b1;
assign ri = alu_ri;
assign rj = alu_rj;
assign ri_id = alu_riid;
assign rj_id = alu_rjid;

mult_signed mult_signed_inst ( // 5 cycle
  .CLK(clk),
  .A(ri_val),
  .B(rj_val),
  .CE(status >= 2 && alu_uop == 0),
  .SCLR(clear | rst | read_result),  // input wire SCLR
  .P(long_result[0])
);

mult_unsigned mult_unsigned_inst ( // 5 cycle
  .CLK(clk),
  .A(ri_val),
  .B(rj_val),
  .CE(status >= 2 && alu_uop == 1),
  .SCLR(clear | rst | read_result),  // input wire SCLR
  .P(long_result[1])
);

wire    divvalid[3:2];
div_signed div_signed_inst (
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid((status == 9) && (alu_uop == 2)),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(rj_val),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid((status == 9) && (alu_uop == 2)),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(ri_val),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(divvalid[2]),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(div_result[2]),            // output wire [63 : 0] m_axis_dout_tdata
  .aresetn(used)
);

div_unsigned div_unsigned_inst (
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid((status == 9) && (alu_uop == 3)),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(rj_val),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid((status == 9) && (alu_uop == 3)),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(ri_val),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(divvalid[3]),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(div_result[3]),            // output wire [63 : 0] m_axis_dout_tdata
  .aresetn(used)
);
assign long_result[2][31:0] = div_result[2][63:32];
assign long_result[2][63:32] = div_result[2][31:0];
assign long_result[3][31:0] = div_result[3][63:32];
assign long_result[3][63:32] = div_result[3][31:0];

assign result = 0;
assign avail = (status == 8);
assign change_meta = 0;
assign set_nw_meta = 0;
assign exc = 0;
assign excode = 0;

assign muldiv_result = long_result[alu_uop[1:0]];

always @(posedge clk) begin
    if (rst || clear) begin
        status <= 0;
    end
    else begin
        if (status == 0) begin
            if (issue) begin
                alu_ri <= issue_vec[16];
                alu_riid <= issue_vec[22:17];
                alu_rj <= issue_vec[23];
                alu_rjid <= issue_vec[29:24];
                alu_uop <= issue_vec[43:38];
                status <= 1;
            end
        end
        else if (status == 1) begin
            if (ri_avail && rj_avail) begin
                if (alu_uop == 0 || alu_uop == 1) status <= 2;  // MUL
                else status <= 9;   // DIV
            end
        end // 8
        else if (status == 8) begin
            if (read_result) begin
                status <= 0;
            end
        end
        else if (status == 9) begin
            if (divvalid[alu_uop]) begin    // valid
                status <= 8;
            end
        end
        else begin
            status <= status + 1;
        end
    end
end


endmodule

