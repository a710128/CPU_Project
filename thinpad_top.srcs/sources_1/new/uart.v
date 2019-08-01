`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/22 22:18:22
// Design Name: 
// Module Name: uart
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


module uart(
    input wire          clk_100M,           //50MHz 时钟输入
    input wire          rst,
    
    //直连串口信号
    output wire         txd,  //直连串口发送端
    input  wire         rxd,  //直连串口接收端
    
    input  wire         uart_data_read,
    output wire         uart_data_ready,
    output reg[7:0]     uart_data_in,
    
    input  wire         uart_data_write,
    input  wire[7:0]    uart_data_out,
    output wire         uart_busy
);

parameter CLK_FREQ = 60000000;
    
//直连串口接收发送演示，从直连串口收到的数据再发送出去
wire [7:0] ext_uart_rx;
reg  [7:0] ext_uart_tx;
wire ext_uart_ready, ext_uart_busy;
reg ext_uart_start, ex_uart_clear;
reg [7:0]   uart_read_buffer;
reg         read_buffer_ready;
assign uart_data_ready = read_buffer_ready;

async_receiver #(.ClkFrequency(CLK_FREQ),.Baud(115200)) //接收模块，9600无检验位
    ext_uart_r(
        .clk(clk_100M),                      //外部时钟信号
        .RxD(rxd),                          //外部串行信号输入
        .RxD_data_ready(ext_uart_ready),    //数据接收到标志
        .RxD_clear(ex_uart_clear),          //清除接收标志
        .RxD_data(ext_uart_rx),             //接收到的一字节数据
        .RxD_idle(),
        .RxD_endofpacket()
    );
always @(posedge clk_100M) begin //将缓冲区ext_uart_buffer发送出去
    if (rst) begin
        ex_uart_clear <= 1;
        read_buffer_ready <= 0;
        uart_read_buffer <= 0;
    end
    if (ext_uart_ready) begin
        ex_uart_clear <= 1;
        uart_read_buffer <= ext_uart_rx;
        read_buffer_ready <= 1;
    end
    else begin
        ex_uart_clear <= 0;
    end
    
    if (uart_data_read) begin   
        read_buffer_ready <= 0;
    end
end

always @(*) begin
    if (uart_data_read) begin
        uart_data_in <= uart_read_buffer;    // put data
    end
    else begin
        uart_data_in <= 0;
    end
end

assign uart_busy = ext_uart_busy;
always @(posedge clk_100M) begin //将缓冲区ext_uart_buffer发送出去
    if (uart_data_write && !ext_uart_busy) begin
        ext_uart_tx <= uart_data_out;
        ext_uart_start <= 1;
    end
    else begin
        ext_uart_start <= 0;
    end

end

async_transmitter #(.ClkFrequency(CLK_FREQ),.Baud(115200)) //发送模块，9600无检验位
    ext_uart_t(
    .clk(clk_100M),                      //外部时钟信号
    .TxD(txd),                          //串行信号输出
    .TxD_busy(ext_uart_busy),           //发送器忙状态指示
    .TxD_start(ext_uart_start),         //开始发送信号
    .TxD_data(ext_uart_tx)              //待发送的数据
);
    
endmodule
