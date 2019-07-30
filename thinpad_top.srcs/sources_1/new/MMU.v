module MMU(
    input wire clk,
    input wire rst,
    
    input wire if_read,
    input wire if_write,
    
    // TLB
    input wire[31:0] vaddr,
    input wire is_IF,
    input wire[31:0] rollback_pc,
    input wire tlb_write,
    input wire[3:0] tlb_write_idx,
    input wire[95:0] tlb_write_entry,
    input wire[7:0] current_asid,
    output wire[66:0]  tlb_miss, // { is_store, is_IF, is_miss, epc, BVA}
    
    input wire[31:0] input_data,
    input wire[4:0] bytemode,
    output reg[31:0] output_data = 32'h00000000,
    
    inout wire[31:0] base_ram_data,
    output wire[19:0] base_ram_addr,
    output wire[3:0] base_ram_be_n,
    output wire base_ram_ce_n,
    output wire base_ram_oe_n,
    output wire base_ram_we_n,

    inout wire[31:0] ext_ram_data,
    output wire[19:0] ext_ram_addr,
    output wire[3:0] ext_ram_be_n,
    output wire ext_ram_ce_n,
    output wire ext_ram_oe_n,
    output wire ext_ram_we_n,
    
    // on-chip rom
    input wire[31:0]    rom_data,
    output reg          rom_ce,
    output reg[9:0]    rom_addr,
    
    output wire uart_rdn,
    output wire uart_wrn,
    input wire uart_dataready,
    input wire uart_tbre,
    input wire uart_tsre,
    
    output wire[15:0] debug_leds,
    output wire[7:0] debug_dpys,
    
    // 键盘(伪)
    input wire key_down,
    input wire[7:0] spec_key,
    output reg key_get,
    
    //图像输出信号
    output wire[2:0] video_red,    //红色像素，3位
    output wire[2:0] video_green,  //绿色像素，3位
    output wire[1:0] video_blue,   //蓝色像素，2位
    output wire video_hsync,       //行同步（水平同步）信号
    output wire video_vsync,       //场同步（垂直同步）信号
    output wire video_clk,         //像素时钟输出
    output wire video_de,           //行数据有效信号，用于区分消隐区
    
    // TLBP. TLBR
    input wire tlbp_query,
    input wire tlbr_query,
    output wire[4:0] tlb_query_idx,
    output wire[95:0] tlb_query_entry,

    // flash
    inout  wire [15:0]flash_d,      //Flash数据
    output wire [22:0]flash_a,      //Flash地址，a0仅在8bit模式有效，16bit模式无意义
    output wire flash_rp_n,         //Flash复位信号，低有效
    output wire flash_vpen,         //Flash写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,         //Flash片选信号，低有效
    output wire flash_oe_n,         //Flash读使能信号，低有效
    output wire flash_we_n,         //Flash写使能信号，低有效
    output wire flash_byte_n,      //Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1
    
    input  wire inst_commit
    );

/* ===================== Counter ==================== */
parameter CPU_US_COUNT = 10;
reg[63:0]       cycle_counter;
wire[31:0]      cycle_counter_lo;
wire[31:0]      cycle_counter_hi;
assign cycle_counter_lo = cycle_counter[31:0];
assign cycle_counter_hi = cycle_counter[63:32];
reg[7:0]        cpu_ns_count;
reg[63:0]       cpu_us_counter;
wire[31:0]      us_counter_lo;
wire[31:0]      us_counter_hi;
assign us_counter_lo = cpu_us_counter[31:0];
assign us_counter_hi = cpu_us_counter[63:32];
reg[63:0]       inst_counter;
wire[31:0]      inst_counter_lo;
wire[31:0]      inst_counter_hi;
assign inst_counter_lo = inst_counter[31:0];
assign inst_counter_hi = inst_counter[63:32];
always @(posedge clk) begin
    if (!rst) begin
        cpu_ns_count <= 8'b1;
        cpu_us_counter <= 64'b0;
        cycle_counter <= 64'b0;
        inst_counter <= 64'b0;
    end
    else begin
        cycle_counter <= cycle_counter + 64'b1;
        if (inst_commit) begin
            inst_counter <= inst_counter + 64'b1;
        end
        if (cpu_ns_count == CPU_US_COUNT) begin
            cpu_ns_count <= 8'b1;
            cpu_us_counter <= cpu_us_counter + 64'b1;
        end
        else begin
            cpu_ns_count <= cpu_ns_count + 8'b1;
        end
    end
    
end


reg tlb_enabled;
wire[25:0] tlb_paddr;
reg[37:0] paddr;
(*keep = "TRUE"*) wire[31:0] addr;

assign addr = paddr[31:0];
assign tlb_miss[63: 32] = rollback_pc;
assign tlb_miss[31: 0] = vaddr;
assign tlb_miss[65] = is_IF;
assign tlb_miss[66] = if_write;

TLB J_TLB (
    .clk(clk),
    .rst(rst),
    .tlb_query(tlb_enabled),
    .tlb_query_vpn(vaddr[31:12]),
    
    .tlb_write(tlb_write),
    .tlb_index(tlb_write_idx),
    .tlb_entry(tlb_write_entry),
    
    .current_asid(current_asid),
    
    .tlb_pfn(tlb_paddr),
    .tlb_miss(tlb_miss[64]),
    
    .tlbp_query(tlbp_query),
    .tlbr_query(tlbr_query),
    .tlb_query_idx(tlb_query_idx),
    .tlb_query_entry(tlb_query_entry)
);

always @(*) begin
    if (!(if_read || if_write)) begin   // no read/write
        // do nothing
        paddr <= {6'b0, vaddr};
        tlb_enabled <= 0;
    end
    else if ((vaddr >= 32'h80000000) && (vaddr < 32'hC0000000)) begin
        // unmapped
        paddr <= {9'b0, vaddr[28:0]};
        tlb_enabled <= 0;
    end
    else begin
        tlb_enabled <= 1;
        paddr <= {tlb_paddr, vaddr[11:0]};
    end
end


reg oe1 = 1'b1, we1 = 1'b1, ce1 = 1'b1;
reg oe2 = 1'b1, we2 = 1'b1, ce2 = 1'b1;
wire[3:0] be = ~bytemode[3:0];
reg[31:0] ram_write_data = 32'h00000000;
reg[15:0] flash_d_write = 16'h0000;
reg wrn = 1'b1, rdn = 1'b1;

assign base_ram_addr = addr[21:2];
assign ext_ram_addr  = addr[21:2];

assign base_ram_data = if_write ? ram_write_data : 32'bz;
assign ext_ram_data  = if_write ? ram_write_data : 32'bz;
assign flash_d = if_write ? flash_d_write : 32'bz;

assign flash_vpen = 1'b1;

assign base_ram_ce_n = ce1;
assign base_ram_oe_n = oe1;
assign base_ram_we_n = we1;
assign base_ram_be_n = be;

assign ext_ram_ce_n = ce2;
assign ext_ram_oe_n = oe2;
assign ext_ram_we_n = we2;
assign ext_ram_be_n = be;

assign uart_wrn     = wrn;
assign uart_rdn     = rdn;

reg[15:0] leds = 16'h0000;
reg[7:0] dpys = 8'h00;
assign debug_leds   = leds;
assign debug_dpys   = dpys;

wire[31:0] ram_read_data = addr[22] ? ext_ram_data : base_ram_data;

reg flash_rp_n1 = 1'b1; reg flash_ce_n1 = 1'b1; reg flash_oe_n1 = 1'b1;
reg flash_byte_n1 = 1'b1; reg flash_we_n1 = 1'b1; reg[22:0] flash_a1 = 23'b0;
assign flash_rp_n = flash_rp_n1;
assign flash_ce_n = flash_ce_n1;
assign flash_oe_n = flash_oe_n1;
assign flash_byte_n = flash_byte_n1;
assign flash_we_n = flash_we_n1;
assign flash_a = flash_a1;

always @(*) begin
    key_get <= 0;
    
    if ((!clk) && (!tlb_miss[64])) begin    // STOP if TLB miss
        oe1 <= 1'b1;
        oe2 <= 1'b1;
        we1 <= 1'b1;
        we2 <= 1'b1;
        
        rom_ce <= 0;
        
        // flash_rp_n1 <= 1'b1;
        flash_ce_n1 <= 1'b0;
        flash_oe_n1 <= 1'b1;
        flash_we_n1 <= 1'b1;
        flash_byte_n1 <= 1'b1;
        
        if (addr[31:16] == 16'h1FD0) begin
            ce1 <= 1'b1;
            ce2 <= 1'b1;
            rdn <= 1'b1;
            wrn <= 1'b1;
            output_data <= 32'h00000000;
            ram_write_data <= 32'h00000000;
            case (addr[15:0])
            16'h0400, 16'h0408: begin
                // LED & DPY % vga
            end
            16'h03F8: begin
                if (if_read) begin
                    rdn <= 1'b0;
                    wrn <= 1'b1;
                    output_data <= {24'b0, base_ram_data[7:0]};
                end
                else if (if_write) begin
                    rdn <= 1'b1;
                    wrn <= 1'b0;
                    ram_write_data <= input_data;
                end
            end
            16'h03FC: begin
                rdn <= 1'b1;
                wrn <= 1'b1;
                if (if_read) begin
                    output_data <= {30'b0, uart_dataready, uart_tbre & uart_tsre};
                end
            end
            16'h0500: begin // cycle lo
                output_data <= cycle_counter_lo;
            end
            16'h0504: begin // cycle hi
                output_data <= cycle_counter_hi;
            end
            16'h0600: begin // us lo
                output_data <= us_counter_lo;
            end
            16'h0604: begin // us hi
                output_data <= us_counter_hi;
            end
            16'h0700: begin // inst lo
                output_data <= inst_counter_lo;
            end
            16'h0704: begin // inst hi
                output_data <= inst_counter_hi;
            end
            endcase
        end
        else if (addr[31:16] < 16'h0080) begin // RAM
            ram_write_data <= 32'h00000000;
            // RAM
            ce1 <= addr[22];
            ce2 <= ~addr[22];
            oe1 <= addr[22] | (~if_read);
            oe2 <= (~addr[22]) | (~if_read);
            we1 <= addr[22] | (~if_write);
            we2 <= (~addr[22]) | (~if_write);
            rdn <= 1'b1;
            wrn <= 1'b1;
            if (if_read) begin
                case (bytemode)
                    5'b01000: output_data <= {{24{ram_read_data[31]}}, ram_read_data[31:24]};
                    5'b11000: output_data <= {24'h000000, ram_read_data[31:24]};
                    5'b00100: output_data <= {{24{ram_read_data[23]}}, ram_read_data[23:16]};
                    5'b10100: output_data <= {24'h000000, ram_read_data[23:16]};
                    5'b00010: output_data <= {{24{ram_read_data[15]}}, ram_read_data[15:8]};
                    5'b10010: output_data <= {24'h000000, ram_read_data[15:8]};
                    5'b00001: output_data <= {{24{ram_read_data[7]}}, ram_read_data[7:0]};
                    5'b10001: output_data <= {24'h000000, ram_read_data[7:0]};
                    
                    5'b01100: output_data <= {{16{ram_read_data[31]}}, ram_read_data[31:16]};
                    5'b11100: output_data <= {16'h0000, ram_read_data[31:16]};
                    5'b00011: output_data <= {{16{ram_read_data[15]}}, ram_read_data[15:0]};
                    5'b10011: output_data <= {16'h0000, ram_read_data[15:0]};
                    
                    default: output_data <= ram_read_data;
                endcase
            end
            else if (if_write) begin
                output_data <= 32'h00000000;
                case (bytemode[3:0])
                    4'b1000: ram_write_data <= {input_data[7:0], 24'h000000};
                    4'b0100: ram_write_data <= {8'h00, input_data[7:0], 16'h0000};
                    4'b0010: ram_write_data <= {16'h0000, input_data[7:0], 8'h00};
                    4'b0001: ram_write_data <= {24'h000000, input_data[7:0]};
                    
                    4'b1100: ram_write_data <= {input_data[15:0], 16'h0000};
                    4'b0011: ram_write_data <= {16'h0000, input_data[15:0]};
                    
                    default: ram_write_data <= input_data;
                endcase
            end
            else begin
                output_data <= 32'h00000000;
                ram_write_data <= 32'h00000000;
            end
        end
        else if (addr[31:24] == 8'h1E ) begin   // FLASH
            flash_a1 <= addr[23:1];     //Flash地址，a0仅在8bit模式有效，16bit模式无意义
            // flash_ce_n1 <= 1'b0;         //Flash片选信号，低有效           
            
            if (if_read) begin
                flash_oe_n1 <= 1'b0;
                case (bytemode)
                    5'b01000: output_data <= 32'b0;
                    5'b11000: output_data <= 32'b0;
                    5'b00100: output_data <= 32'b0;
                    5'b10100: output_data <= 32'b0;
                    5'b00010: output_data <= {{24{flash_d[15]}}, flash_d[15:8]};
                    5'b10010: output_data <= {24'h000000, flash_d[15:8]};
                    5'b00001: output_data <= {{24{flash_d[7]}}, flash_d[7:0]};
                    5'b10001: output_data <= {24'h000000, flash_d[7:0]};
                    
                    5'b01100: output_data <= 32'b0;
                    5'b11100: output_data <= 32'b0;
                    5'b00011: output_data <= {{16{flash_d[15]}}, flash_d[15:0]};
                    5'b10011: output_data <= {16'h0000, flash_d[15:0]};
                    
                    default: output_data <= {16'h0000, flash_d};
                endcase
            end
            else if (if_write) begin
                flash_we_n1 <= 1'b0;
                output_data <= 32'h00000000;
                case (bytemode[3:0])
                    4'b1000: flash_d_write <= 16'h0000;
                    4'b0100: flash_d_write <= 16'h0000;
                    4'b0010: flash_d_write <= {input_data[7:0], 8'h00};
                    4'b0001: flash_d_write <= {8'h000000, input_data[7:0]};
                    
                    4'b1100: flash_d_write <= 16'h0000;
                    4'b0011: flash_d_write <= input_data[15:0];
                    
                    default: flash_d_write <= input_data[15:0];
                endcase
            end
            else begin
                output_data <= 32'h00000000;
                flash_d_write <= 16'h0000;
            end
            
        end
        else if (addr[31:12] == 20'h1FC00) begin // on-chip ROM
            rom_ce <= 1;
            rom_addr <= addr[11:2];
            output_data <= rom_data;
        end
        else if (addr[31:12] == 20'h1FC03) begin // char-VGA
        end
        else if (addr[31:16] == 16'h0F00 ) begin // PS2 
        end
    end
    else begin
        // ram
        ce1 <= 1'b1;
        ce2 <= 1'b1;
        oe1 <= 1'b1;
        oe2 <= 1'b1;
        we1 <= 1'b1;
        we2 <= 1'b1;
        rdn <= 1'b1;
        wrn <= 1'b1;
        output_data <= 32'h00000000;
        ram_write_data <= 32'h00000000;
    end
end

reg [63:0] chr_signal_input1;
reg [63:0] chr_signal_input2;

always@(posedge clk) begin
    if (if_write) begin
        case (addr)
            32'h1FD00400: leds <= input_data[15:0];
            32'h1FD00408: dpys <= input_data[7:0];
            
            32'h1FD02000: begin
                chr_signal_input1[63:56] <= input_data[7:0];
            end
            32'h1FD02001: begin
                chr_signal_input1[55:48] <= input_data[7:0];
            end
            32'h1FD02002: begin
                chr_signal_input1[47:40] <= input_data[7:0];
            end
            32'h1FD02003: begin
                chr_signal_input1[39:32] <= input_data[7:0];
            end
            32'h1FD02004: begin
                chr_signal_input1[31:24] <= input_data[7:0];
            end
            32'h1FD02005: begin
                chr_signal_input1[23:16] <= input_data[7:0];
            end
            32'h1FD02006: begin
                chr_signal_input1[15:8] <= input_data[7:0];
            end
            32'h1FD02007: begin
                chr_signal_input1[7:0] <= input_data[7:0];
            end
            32'h1FD02010: begin
                chr_signal_input2[63:56] <= input_data[7:0];
            end
            32'h1FD02011: begin
                chr_signal_input2[55:48] <= input_data[7:0];
            end
            32'h1FD02012: begin
                chr_signal_input2[47:40] <= input_data[7:0];
            end
            32'h1FD02013: begin
                chr_signal_input2[39:32] <= input_data[7:0];
            end
            32'h1FD02014: begin
                chr_signal_input2[31:24] <= input_data[7:0];
            end
            32'h1FD02015: begin
                chr_signal_input2[23:16] <= input_data[7:0];
            end
            32'h1FD02016: begin
                chr_signal_input2[15:8] <= input_data[7:0];
            end
            32'h1FD02017: begin
                chr_signal_input2[7:0] <= input_data[7:0];
            end
        endcase
    end
end

vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at75 (
    .clk(clk),
    .enable(1'b1),
    .signal_input({chr_signal_input1, chr_signal_input2}),
    .video_red(video_red),
    .video_green(video_green),
    .video_blue(video_blue),
    .video_hsync(video_hsync),
    .video_vsync(video_vsync),
    .video_clk(video_clk),
    .video_de(video_de),
    
    .reset(1'b0)
);

endmodule
