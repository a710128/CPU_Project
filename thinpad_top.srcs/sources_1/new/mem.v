`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/07/22 21:55:53
// Design Name: 
// Module Name: mem
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


module mem(
    input wire          clk_50M,
    input wire          rst,

    // Interface
    input wire          if_ce,
    input wire          mem_ce,
    input wire          mem_we,
    
    input wire[31:0]    if_addr,
    input wire[31:0]    mem_addr,
    input wire[31:0]    mem_data_write,
    input wire[3:0]     mem_bytemode,
    
    output wire[31:0]   if_data,
    output wire[31:0]   mem_data,
    output wire         if_skip,
    output wire         mem_valid,
    
    // I/O Port
    
    //BaseRAM信号
    inout wire[31:0] base_ram_data,  //BaseRAM数据，低8位与CPLD串口控制器共享
    output wire[19:0] base_ram_addr, //BaseRAM地址
    output wire[3:0] base_ram_be_n,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire base_ram_ce_n,       //BaseRAM片选，低有效
    output wire base_ram_oe_n,       //BaseRAM读使能，低有效
    output wire base_ram_we_n,       //BaseRAM写使能，低有效

    //ExtRAM信号
    inout wire[31:0] ext_ram_data,  //ExtRAM数据
    output wire[19:0] ext_ram_addr, //ExtRAM地址
    output wire[3:0] ext_ram_be_n,  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire ext_ram_ce_n,       //ExtRAM片选，低有效
    output wire ext_ram_oe_n,       //ExtRAM读使能，低有效
    output wire ext_ram_we_n,       //ExtRAM写使能，低有效

    // UART
    output wire         uart_data_read,
    input  wire         uart_data_ready,
    input  wire[7:0]    uart_data_in,
    
    output wire         uart_data_write,
    output wire[7:0]    uart_data_out,
    input  wire         uart_busy,

    //Flash存储器信号，参考 JS28F640 芯片手册
    output wire [22:0]flash_a,      //Flash地址，a0仅在8bit模式有效，16bit模式无意义
    inout  wire [15:0]flash_d,      //Flash数据
    output wire flash_rp_n,         //Flash复位信号，低有效
    output wire flash_vpen,         //Flash写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,         //Flash片选信号，低有效
    output wire flash_oe_n,         //Flash读使能信号，低有效
    output wire flash_we_n,         //Flash写使能信号，低有效
    output wire flash_byte_n,       //Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

    //USB 控制器信号，参考 SL811 芯片手册
    output wire sl811_a0,
    //inout  wire[7:0] sl811_d,     //USB数据线与网络控制器的dm9k_sd[7:0]共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    //网络控制器信号，参考 DM9000A 芯片手册
    output wire dm9k_cmd,
    inout  wire[15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input  wire dm9k_int,
    
    // 
    output wire[15:0] leds,         //16位LED，输出时1点亮
    output wire[7:0]  dpy_number    //数码管显示数值
);

/* ====================== input ===================== */
reg         i_mem_req;
reg[3:0]    i_cnt_req;
reg[2:0]    i_output_sel;

reg[19:0]   i_base_ram_addr,    i_ext_ram_addr;
reg[31:0]   i_base_ram_data,    i_ext_ram_data;
reg[3:0]    i_bytemode;
reg         i_base_ram_ce_n, i_base_ram_oe_n, i_base_ram_we_n;
reg         i_ext_ram_ce_n, i_ext_ram_oe_n, i_ext_ram_we_n;         
reg         i_uart_data_read,   i_uart_data_write;
reg[7:0]    i_uart_data_out;

reg[22:0]   i_flash_a;
reg[15:0]   i_flash_d;
reg         i_flash_ce_n, i_flash_oe_n, i_flash_we_n;

reg[15:0]   i_leds;
reg[7:0]    i_dpy_number;


/* ====================== output ===================== */

reg         o_mem_req;
reg[3:0]    o_cnt_req;
reg[2:0]    o_output_sel;

reg[19:0]   o_base_ram_addr,    o_ext_ram_addr;
reg[31:0]   o_base_ram_data,    o_ext_ram_data;
reg[3:0]    o_bytemode;
reg         o_base_ram_ce_n, o_base_ram_oe_n, o_base_ram_we_n;
reg         o_ext_ram_ce_n, o_ext_ram_oe_n, o_ext_ram_we_n;         
reg         o_uart_data_read,   o_uart_data_write;
reg[7:0]    o_uart_data_out;

reg[22:0]   o_flash_a;
reg[15:0]   o_flash_d;
reg         o_flash_ce_n, o_flash_oe_n, o_flash_we_n;

reg[15:0]   o_leds;
reg[7:0]    o_dpy_number;

/*  ======================== output selector =======================  */
wire[31:0]  data_in[5:0];
assign  data_in[0] = 0;
assign  data_in[1] = base_ram_data;
assign  data_in[2] = ext_ram_data;
assign  data_in[3] = {24'b0, uart_data_in};
assign  data_in[4] = {16'b0, flash_d};
assign  data_in[5] = {30'b0, uart_data_ready, uart_busy};

wire[31:0]  output_data_n;
reg[31:0]   output_data;
assign  output_data_n = data_in[o_output_sel]; // 0: on input, 1: BASE ram, 2: EXT ram, 3: UART data, 4: flash, 5 UART status 

always @(*) begin   // 根据Bytemode调整输出
    case (o_bytemode)
        5'b01000: output_data <= {{24{output_data_n[31]}}, output_data_n[31:24]};
        5'b11000: output_data <= {24'h000000, output_data_n[31:24]};
        5'b00100: output_data <= {{24{output_data_n[23]}}, output_data_n[23:16]};
        5'b10100: output_data <= {24'h000000, output_data_n[23:16]};
        5'b00010: output_data <= {{24{output_data_n[15]}}, output_data_n[15:8]};
        5'b10010: output_data <= {24'h000000, output_data_n[15:8]};
        5'b00001: output_data <= {{24{output_data_n[7]}}, output_data_n[7:0]};
        5'b10001: output_data <= {24'h000000, output_data_n[7:0]};
        
        5'b01100: output_data <= {{16{output_data_n[31]}}, output_data_n[31:16]};
        5'b11100: output_data <= {16'h0000, output_data_n[31:16]};
        5'b00011: output_data <= {{16{output_data_n[15]}}, output_data_n[15:0]};
        5'b10011: output_data <= {16'h0000, output_data_n[15:0]};
        
        default: output_data <= output_data_n;
    endcase
end

reg[31:0] bytemode_mem_data;
always @(*) begin
    case (mem_bytemode[3:0])
        4'b1000: bytemode_mem_data <= {mem_data_write[7:0], 24'h000000};
        4'b0100: bytemode_mem_data <= {8'h00, mem_data_write[7:0], 16'h0000};
        4'b0010: bytemode_mem_data <= {16'h0000, mem_data_write[7:0], 8'h00};
        4'b0001: bytemode_mem_data <= {24'h000000, mem_data_write[7:0]};
        
        4'b1100: bytemode_mem_data <= {mem_data_write[15:0], 16'h0000};
        4'b0011: bytemode_mem_data <= {16'h0000, mem_data_write[15:0]};
        
        default: bytemode_mem_data <= mem_data_write;
    endcase
end

/* =================== Assign =================== */
assign base_ram_data = o_base_ram_oe_n ? o_base_ram_data : 32'bz;
assign base_ram_addr = o_base_ram_addr;
assign base_ram_be_n = ~o_bytemode[3:0];
assign base_ram_ce_n = o_base_ram_ce_n;
assign base_ram_oe_n = o_base_ram_oe_n;
assign base_ram_we_n = o_base_ram_we_n;

assign ext_ram_data = o_ext_ram_oe_n ? o_ext_ram_data : 32'bz;
assign ext_ram_addr = o_ext_ram_addr;
assign ext_ram_be_n = ~o_bytemode[3:0];
assign ext_ram_ce_n = o_ext_ram_ce_n;
assign ext_ram_oe_n = o_ext_ram_oe_n;
assign ext_ram_we_n = o_ext_ram_we_n;

assign uart_data_read = o_uart_data_read;
assign uart_data_write = o_uart_data_write;
assign uart_data_out = o_uart_data_out;

assign flash_a = o_flash_a;
assign flash_d = o_flash_oe_n ? o_flash_d : 16'bz;
assign flash_rp_n = 1;
assign flash_vpen = 1;
assign flash_ce_n = o_flash_ce_n;
assign flash_oe_n = o_flash_oe_n;
assign flash_we_n = o_flash_we_n;
assign flash_byte_n = 1;

assign leds = o_leds;
assign dpy_number = o_dpy_number;

assign  if_data = o_mem_req ? 32'b0 : output_data_n;
assign  mem_data = o_mem_req ? output_data : 32'b0;
assign  if_skip = o_mem_req;
assign  mem_valid =  (o_cnt_req == 0) ? 1 : 0;

/* =================== Assign =================== */


always @(*) begin
    i_base_ram_ce_n <= 1;
    i_ext_ram_ce_n <= 1;
    i_flash_ce_n <= 1;
    i_uart_data_read <= 0;
    i_uart_data_write <= 0;
    i_output_sel <= 0;
    i_cnt_req <= 0;
    
    if (mem_ce) begin
        i_mem_req <= 1;
        if (mem_addr[31:16] == 16'h1FD0) begin
            case (mem_addr[15 : 0])
                16'h0400: begin // LED
                    i_leds <= bytemode_mem_data[15:0];
                    i_cnt_req <= 0;
                end
                16'h0408: begin // DPY
                    i_dpy_number <= bytemode_mem_data[7:0];
                    i_cnt_req <= 0;
                end
                16'h03F8: begin // UART
                    if (mem_we) begin
                        i_cnt_req <= 0;
                        i_uart_data_write <= 1;
                        i_uart_data_out <= bytemode_mem_data[7:0];
                    end
                    else begin
                        i_cnt_req <= 1;
                        i_output_sel <= 3;
                        i_uart_data_read <= 1;
                    end
                end
                16'h03FC: begin // UART status
                    i_cnt_req <= 0;
                    i_output_sel <= 5;
                end
            endcase
        end
        else if (mem_addr[31 : 16] < 16'h0080) begin    // RAM
            i_cnt_req <= 0;
            if (mem_addr[22]) begin
                // EXT ram
                i_ext_ram_ce_n <= 0;
                i_ext_ram_addr <= mem_addr[21:2];
                i_ext_ram_data <= bytemode_mem_data;
                
                i_ext_ram_oe_n <= mem_we;
                i_ext_ram_we_n <= ~mem_we;
                i_bytemode <= mem_bytemode;
                i_output_sel <= 2;
            end
            else begin
                // BASE ram
                i_base_ram_ce_n <= 0;
                i_base_ram_addr <= mem_addr[21:2];
                i_base_ram_data <= bytemode_mem_data;
                
                i_base_ram_oe_n <= mem_we;
                i_base_ram_we_n <= ~mem_we;
                i_bytemode <= mem_bytemode;
                i_output_sel <= 1;
            end
        end
        else if (mem_addr[31:24] == 8'h1E) begin    // FLASH
            i_cnt_req <= 3;
            
            i_flash_ce_n <= 0;
            i_flash_a <= mem_addr[23:1];
            i_flash_d <= bytemode_mem_data[15:0];
            i_flash_oe_n <= mem_we;
            i_flash_we_n <= ~mem_we;
            i_output_sel <= 4;
        end
        else if (mem_addr[31:12] == 20'h1FC00) begin // on-chip ROM
            
        end
    end
    else begin
        i_mem_req <= 0;
        if (if_ce) begin        // Inst Fetch
            i_cnt_req <= 0;
            
            if (if_addr[31 : 16] < 16'h0080) begin    // RAM
                if (if_addr[22]) begin
                    // EXT ram
                    i_ext_ram_ce_n <= 0;
                    i_ext_ram_addr <= if_addr[21:2];
                    i_ext_ram_data <= 0;
                    
                    i_ext_ram_oe_n <= 0;
                    i_ext_ram_we_n <= 1;
                    i_bytemode <= 5'b01111;
                    i_output_sel <= 2;
                end
                else begin
                    // BASE ram
                    i_base_ram_ce_n <= 0;
                    i_base_ram_addr <= if_addr[21:2];
                    i_base_ram_data <= 0;
                    
                    i_base_ram_oe_n <= 0;
                    i_base_ram_we_n <= 1;
                    i_bytemode <= 5'b01111;
                    i_output_sel <= 1;
                end
            end
            else if (mem_addr[31:12] == 20'h1FC00) begin // on-chip ROM
            end
        end
    end
end

always @(posedge clk_50M) begin
    if (rst) begin
        o_mem_req <= 0;
        o_cnt_req <= 0;
        o_output_sel <= 0;
        o_base_ram_addr <= 0;
        o_ext_ram_addr <= 0;
        o_base_ram_data <= 0;
        o_ext_ram_data <= 0;
        o_bytemode <= 0;
        o_base_ram_ce_n <= 1;
        o_ext_ram_ce_n <= 1;
        o_base_ram_oe_n <= 1;
        o_ext_ram_oe_n <= 1;
        o_base_ram_we_n <= 1;
        o_ext_ram_we_n <= 1;
        o_uart_data_read <= 0;
        o_uart_data_write <= 0;
        o_uart_data_out <= 0;
        o_flash_a <= 0;
        o_flash_d <= 0;
        o_flash_ce_n <= 1;
        o_flash_oe_n <= 1;
        o_flash_we_n <= 1;
        o_leds <= 0;
        o_dpy_number <= 0;
    end
    else if (o_cnt_req) begin
        o_cnt_req <= o_cnt_req - 1;
    end
    else begin
        o_mem_req <= i_mem_req;
        o_cnt_req <= i_cnt_req;
        o_output_sel <= i_output_sel;
        o_base_ram_addr <= i_base_ram_addr;
        o_ext_ram_addr <= i_ext_ram_addr;
        o_base_ram_data <= i_base_ram_data;
        o_ext_ram_data <= i_ext_ram_data;
        o_bytemode <= i_bytemode;
        o_base_ram_ce_n <= i_base_ram_ce_n;
        o_ext_ram_ce_n <= i_ext_ram_ce_n;
        o_base_ram_oe_n <= i_base_ram_oe_n;
        o_ext_ram_oe_n <= i_ext_ram_oe_n;
        o_base_ram_we_n <= i_base_ram_we_n;
        o_ext_ram_we_n <= i_ext_ram_we_n;
        o_uart_data_read <= i_uart_data_read;
        o_uart_data_write <= i_uart_data_write;
        o_uart_data_out <= i_uart_data_out;
        o_flash_a <= i_flash_a;
        o_flash_d <= i_flash_d;
        o_flash_ce_n <= i_flash_ce_n;
        o_flash_oe_n <= i_flash_oe_n;
        o_flash_we_n <= i_flash_we_n;
        o_leds <= i_leds;
        o_dpy_number <= i_dpy_number;
    end
end

endmodule

