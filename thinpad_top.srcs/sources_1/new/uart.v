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
    input wire          clk_50M,           //50MHz ʱ������
    input wire          rst,
    
    //ֱ�������ź�
    output wire         txd,  //ֱ�����ڷ��Ͷ�
    input  wire         rxd,  //ֱ�����ڽ��ն�
    
    input  wire         uart_data_read,
    output wire         uart_data_ready,
    output reg[7:0]     uart_data_in,
    
    input  wire         uart_data_write,
    input  wire[7:0]    uart_data_out,
    output wire         uart_busy
);
    
//ֱ�����ڽ��շ�����ʾ����ֱ�������յ��������ٷ��ͳ�ȥ
wire [7:0] ext_uart_rx;
reg  [7:0] ext_uart_tx;
wire ext_uart_ready, ext_uart_busy;
reg ext_uart_start, ex_uart_clear;
reg [7:0]   uart_read_buffer;
reg         read_buffer_ready;
assign uart_data_ready = read_buffer_ready;

async_receiver #(.ClkFrequency(50000000),.Baud(115200)) //����ģ�飬9600�޼���λ
    ext_uart_r(
        .clk(clk_50M),                      //�ⲿʱ���ź�
        .RxD(rxd),                          //�ⲿ�����ź�����
        .RxD_data_ready(ext_uart_ready),    //���ݽ��յ���־
        .RxD_clear(ex_uart_clear),          //������ձ�־
        .RxD_data(ext_uart_rx),             //���յ���һ�ֽ�����
        .RxD_idle(),
        .RxD_endofpacket()
    );
always @(posedge clk_50M) begin //��������ext_uart_buffer���ͳ�ȥ
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
always @(posedge clk_50M) begin //��������ext_uart_buffer���ͳ�ȥ
    if (uart_data_write && !ext_uart_busy) begin
        ext_uart_tx <= uart_data_out;
        ext_uart_start <= 1;
    end
    else begin
        ext_uart_start <= 0;
    end

end

async_transmitter #(.ClkFrequency(50000000),.Baud(115200)) //����ģ�飬9600�޼���λ
    ext_uart_t(
    .clk(clk_50M),                      //�ⲿʱ���ź�
    .TxD(txd),                          //�����ź����
    .TxD_busy(ext_uart_busy),           //������æ״ָ̬ʾ
    .TxD_start(ext_uart_start),         //��ʼ�����ź�
    .TxD_data(ext_uart_tx)              //�����͵�����
);
    
endmodule