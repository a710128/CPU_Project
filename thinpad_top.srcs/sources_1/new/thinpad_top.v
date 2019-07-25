`default_nettype none

module thinpad_top(
    input wire clk_50M,           //50MHz 时钟输入
    input wire clk_11M0592,       //11.0592MHz 时钟输入

    input wire clock_btn,         //BTN5手动时钟按钮开关，带消抖电路，按下时为1
    input wire reset_btn,         //BTN6手动复位按钮开关，带消抖电路，按下时为1

    input  wire[3:0]  touch_btn,  //BTN1~BTN4，按钮开关，按下时为1
    input  wire[31:0] dip_sw,     //32位拨码开关，拨到“ON”时为1
    output wire[15:0] leds,       //16位LED，输出时1点亮
    output wire[7:0]  dpy0,       //数码管低位信号，包括小数点，输出1点亮
    output wire[7:0]  dpy1,       //数码管高位信号，包括小数点，输出1点亮

    //CPLD串口控制器信号
    output wire uart_rdn,         //读串口信号，低有效
    output wire uart_wrn,         //写串口信号，低有效
    input wire uart_dataready,    //串口数据准备好
    input wire uart_tbre,         //发送数据标志
    input wire uart_tsre,         //数据发送完毕标志

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

    //直连串口信号
    output wire txd,  //直连串口发送端
    input  wire rxd,  //直连串口接收端

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

    //图像输出信号
    output wire[2:0] video_red,    //红色像素，3位
    output wire[2:0] video_green,  //绿色像素，3位
    output wire[1:0] video_blue,   //蓝色像素，2位
    output wire video_hsync,       //行同步（水平同步）信号
    output wire video_vsync,       //场同步（垂直同步）信号
    output wire video_clk,         //像素时钟输出
    output wire video_de           //行数据有效信号，用于区分消隐区
);
wire    clear;

/* ================ UART ================= */
wire    uart_data_read, uart_data_write;
wire    uart_data_ready, uart_busy;
wire[7:0]   uart_data_in,   uart_data_out;
uart uart_inst (
    .clk_50M(clk_50M),
    .rst(reset_btn),
    .txd(txd),
    .rxd(rxd),
    .uart_data_read(uart_data_read),
    .uart_data_ready(uart_data_ready),
    .uart_data_in(uart_data_in),
    .uart_data_write(uart_data_write),
    .uart_data_out(uart_data_out),
    .uart_busy(uart_busy)
);

/* ================== DPY ================= */
// 7段数码管译码器演示，将number用16进制显示在数码管上面
reg[7:0] dpy_number;
SEG7_LUT segL(.oSEG1(dpy0), .iDIG(dpy_number[3:0])); //dpy0是低位数码管
SEG7_LUT segH(.oSEG1(dpy1), .iDIG(dpy_number[7:4])); //dpy1是高位数码管

/* ================= MMU ================= */
wire[31:0]  next_PC_vaddr;
wire[31:0]  next_PC_paddr;
wire        next_PC_tlbmiss;

wire        mem_ce;     // from exe
wire        mem_write;
wire[31:0]  mem_vaddr;
wire        mem_tlbmiss;
wire        mem_modify_ex;
wire        mem_noexc;

wire[31:0]  mem_paddr;  // to mem
wire[1:0]   mem_exception;

wire[31:0]  cp0_ENTRYHI;    // from cp0
wire        tlbr_qe;
wire[3:0]   tlbr_index;
wire[95:0]  tlbr_result;

wire        tlbp_qe;
wire[4:0]   tlbp_result;

wire        tlb_we;
wire[3:0]   tlb_write_index;
wire[95:0]  tlb_write_entry;


assign mem_tlbmiss = (mem_exception == 2'd2 || mem_exception == 2'd3) ? 1'b1 : 1'b0;
assign mem_modify_ex = (mem_exception == 2'd1) ? 1'b1 : 1'b0;
assign mem_noexc = (mem_exception == 2'd0) ? 1'b1 : 1'b0;

mmu mmu_inst(
    .clk(clk_50M),
    .rst(reset_btn),
    
    // Global
    .current_entryHi(cp0_ENTRYHI),
    
    // IF
    .if_qe(1),
    .if_vaddr(next_PC_vaddr),
    .if_paddr(next_PC_paddr),
    .if_miss(next_PC_tlbmiss),
    
    // Mem
    .mem_qe(mem_ce),
    .mem_is_load(mem_write),
    .mem_vaddr(mem_vaddr),
    .mem_paddr(mem_paddr),
    .mem_tlb_exception(mem_exception),
    
    // TLBP
    .tlbp_qe(tlbp_qe),
    .tlbp_result(tlbp_result),
    
    // TLBR
    .tlbr_qe(tlbr_qe),
    .tlbr_index(tlbr_index),
    .tlbr_result(tlbr_result),
    
    // TLB 修改
    .tlb_we(tlb_we),
    .tlb_write_index(tlb_write_index),
    .tlb_write_entry(tlb_write_entry)    // { EntryHi, EntryLo0, EntryLo1 }
);

/* ================= MEM ================= */
wire        if_ce;
wire[31:0]  if_addr;
wire        if_skip;
wire[31:0]  if_data;


wire[31:0]  mem_data_write; // from exe
wire[4:0]   mem_bytemode;
wire        mem_avail;
wire[31:0]  mem_data_read;

mem mem_inst (
    .clk_50M(clk_50M),
    .rst(reset_btn),

    // Interface
    .if_ce(if_ce),
    .mem_ce(mem_ce && mem_noexc),
    .mem_we(mem_write),
    
    .if_addr(if_addr),
    .mem_addr(mem_paddr),
    .mem_data_write(mem_data_write),
    .mem_bytemode(mem_bytemode),
    
    .if_data(if_data),
    .mem_data(mem_data_read),
    .if_skip(if_skip),  // if insert bubble
    .mem_valid(mem_avail),
    
    // I/O Port
    
    //BaseRAM信号
    .base_ram_data(base_ram_data),  //BaseRAM数据，低8位与CPLD串口控制器共享
    .base_ram_addr(base_ram_addr), //BaseRAM地址
    .base_ram_be_n(base_ram_be_n),  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    .base_ram_ce_n(base_ram_ce_n),       //BaseRAM片选，低有效
    .base_ram_oe_n(base_ram_oe_n),       //BaseRAM读使能，低有效
    .base_ram_we_n(base_ram_we_n),       //BaseRAM写使能，低有效

    //ExtRAM信号
    .ext_ram_data(ext_ram_data),  //ExtRAM数据
    .ext_ram_addr(ext_ram_addr), //ExtRAM地址
    .ext_ram_be_n(ext_ram_be_n),  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    .ext_ram_ce_n(ext_ram_ce_n),       //ExtRAM片选，低有效
    .ext_ram_oe_n(ext_ram_oe_n),       //ExtRAM读使能，低有效
    .ext_ram_we_n(ext_ram_we_n),       //ExtRAM写使能，低有效

    // UART
    .uart_data_read(uart_data_read),
    .uart_data_ready(uart_data_ready),
    .uart_data_in(uart_data_in),
    
    .uart_data_write(uart_data_write),
    .uart_data_out(uart_data_out),
    .uart_busy(uart_busy),

    //Flash存储器信号，参考 JS28F640 芯片手册
    .flash_a(flash_a),      //Flash地址，a0仅在8bit模式有效，16bit模式无意义
    .flash_d(flash_d),      //Flash数据
    .flash_rp_n(flash_rp_n),         //Flash复位信号，低有效
    .flash_vpen(flash_vpen),         //Flash写保护信号，低电平时不能擦除、烧写
    .flash_ce_n(flash_ce_n),         //Flash片选信号，低有效
    .flash_oe_n(flash_oe_n),         //Flash读使能信号，低有效
    .flash_we_n(flash_we_n),         //Flash写使能信号，低有效
    .flash_byte_n(flash_byte_n),       //Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

    //USB 控制器信号，参考 SL811 芯片手册
    .sl811_a0(sl811_a0),
    //inout  wire[7:0] sl811_d,     //USB数据线与网络控制器的dm9k_sd[7:0]共享
    .sl811_wr_n(sl811_wr_n),
    .sl811_rd_n(sl811_rd_n),
    .sl811_cs_n(sl811_cs_n),
    .sl811_rst_n(sl811_rst_n),
    .sl811_dack_n(sl811_dack_n),
    .sl811_intrq(sl811_intrq),
    .sl811_drq_n(sl811_drq_n),

    //网络控制器信号，参考 DM9000A 芯片手册
    .dm9k_cmd(dm9k_cmd),
    .dm9k_sd(dm9k_sd),
    .dm9k_iow_n(dm9k_iow_n),
    .dm9k_ior_n(dm9k_ior_n),
    .dm9k_cs_n(dm9k_cs_n),
    .dm9k_pwrst_n(dm9k_pwrst_n),
    .dm9k_int(dm9k_int),
    
    // 
    .leds(leds),         //16位LED，输出时1点亮
    .dpy_number(dpy_number)    //数码管显示数值
);


/* ================== PC ==================*/

// input
assign if_ce = ~next_PC_tlbmiss;
assign if_addr = next_PC_paddr;
reg         i_if_id_tlbmiss;
reg[31:0]   i_if_id_pc;
wire        i_if_id_noinst;     // no instruction
assign i_if_id_noinst = if_skip;

always @(posedge clk_50M) begin
    i_if_id_tlbmiss <= next_PC_tlbmiss;
    i_if_id_pc <= next_PC_vaddr;
end

/* ============ Fetch/Decode ============= */

reg[31:0]   o_if_id_inst;       // To decode, branch_predictor
reg         o_if_id_tlbmiss;    // To decode
reg[31:0]   o_if_id_pc;         // To decode, branch_predictor
reg         o_if_id_noinst;     // To decode, branch_predictor
reg         o_if_id_ifskip;     // To branch_predictor
wire[31:0]  bp_jump;            // From branch predictor
wire        bp_delay_slot;      // From branch predictor

wire[31:0]  pc_jump_addr;            // 回传实际跳转地址

always @(posedge clk_50M) begin
    if (clear) begin
        o_if_id_tlbmiss <= 0;
        o_if_id_pc <= pc_jump_addr - 32'h4;
        o_if_id_inst <= 0;
        o_if_id_noinst <= 1;
        o_if_id_ifskip <= 0;
    end
    else begin
        o_if_id_tlbmiss <= i_if_id_tlbmiss;
        o_if_id_pc <= i_if_id_pc;
        o_if_id_inst <= if_data;
        o_if_id_noinst <= i_if_id_noinst;
        o_if_id_ifskip <= if_skip;
    end
end

/* ========= Decode ======== */
wire        commit;         // from exe
wire[4:0]   commit_reg;     // from exe
wire[5:0]   commit_regheap; // from exe
wire[63:0]  regheap_status;
wire[7:0]   component_status;
wire[7:0]   buffer_status;

wire        cant_issue, issue, assign_reg, assign_component, issue_ri, issue_rj, issue_delay_slot;  // to exe
wire[2:0]   issue_buffer_id, assign_component_id, issue_commit_op;
wire[4:0]   issue_reg, issue_excode;
wire[5:0]   assign_reg_id, issue_ri_id, issue_rj_id, issue_uop;
wire[31:0]  issue_meta, issue_pc, issue_j;

decoder decoder_inst(
    .clk(clk_50M),
    .rst(reset_btn),
    .clear(clear),              // 清空流水线以及当前指令
    
    // 指令输入
    .inst(o_if_id_inst),
    .if_tlbmiss(o_if_id_tlbmiss),
    .pc(o_if_id_pc),
    .noinst(o_if_id_noinst),
    .pred_jump(bp_jump),          // 分支预测跳转地址
    .is_delay_slot(bp_delay_slot),      // 是否为延迟槽指令
    
    // 指令提交（更新寄存器状态）
    .commit(commit),
    .commit_reg(commit_reg),
    .commit_regheap(commit_regheap),
    
    // 发射指令
    .cant_issue(cant_issue),         // 运算器资源不足
    .issue(issue),
    .issue_buffer_id(issue_buffer_id),
    .issue_reg(issue_reg),          // 发射指令的真实寄存器编号
    .assign_reg(assign_reg),
    .assign_reg_id(assign_reg_id),      // 关联寄存器编号
    .assign_component(assign_component),   
    .assign_component_id(assign_component_id),    //  0~5:    ALU,    6:  BRANCH,     7: MULDIV
    .issue_ri(issue_ri),
    .issue_ri_id(issue_ri_id),
    .issue_rj(issue_rj),
    .issue_rj_id(issue_rj_id),
    .issue_commit_op(issue_commit_op), //   0: nothing,   1: branch,      2:  mem     3.  MFHI/LO,    4.  MTHI/LO,   5. Copy From MULDIV,     6.  CP0 inst in uop,    7. ERET
    .issue_excode(issue_excode),
    .issue_uop(issue_uop),
    .issue_meta(issue_meta), // Immediate 或其他信息
    .issue_pc(issue_pc),
    .issue_j(issue_j),    // 分支预测跳转你地址
    .issue_delay_slot(issue_delay_slot),   // 是否延迟槽指令
    
    // 状态获取
    .regheap_status(regheap_status),     // r0~r55
    .alu_status(component_status[5:0]),
    .branch_status(component_status[6]),
    .muldiv_status(component_status[7]),
    .buffer_status(buffer_status)       // Reorder buffer 使用状态
);

/* ========= EXE Engine =========*/
wire        cp0_ce; // to cp0
wire[2:0]   cp0_inst;
wire[4:0]   cp0_reg;
wire[31:0]  cp0_putval;
wire        cp0_exception;
wire[4:0]   cp0_excode;
wire[31:0]  cp0_exc_pc;
wire[31:0]  cp0_mem_vaddr;
wire        cp0_exc_ds;

wire[31:0]  cp0_result;// from cp0
wire[31:0]  cp0_EBASE;
wire[31:0]  cp0_SR;


exe_top exec_inst(
    .clk(clk_50M),
    .rst(reset_btn),
    
    .issue(issue),
    .issue_buffer_id(issue_buffer_id),
    .issue_vec({issue_delay_slot, issue_j, issue_pc, issue_meta, issue_uop, issue_excode, issue_commit_op, issue_rj_id, issue_rj, issue_ri_id, issue_ri, assign_component_id, assign_component, assign_reg_id, issue_reg, assign_reg}),
    
    .commit(commit),
    .commit_reg(commit_reg),
    .commit_regheap(commit_regheap),
    
    .regheap_status(regheap_status),
    .component_status(component_status),
    .buffer_status(buffer_status),
    
    .mem_ce(mem_ce),
    .mem_write(mem_write),
    .mem_vaddr(mem_vaddr),
    .mem_bytemode(mem_bytemode),
    .mem_write_data(mem_data_write),
    .mem_read_data(mem_data_read),
    .mem_avail(mem_avail),
    .mem_tlbmiss(mem_tlbmiss),
    .mem_modify_ex(mem_modify_ex),      
    
    .hardint(),
    
    // cp0
    .cp0_ce(cp0_ce),
    .cp0_inst(cp0_inst),
    .cp0_reg(cp0_reg),
    .cp0_putval(cp0_putval),
    .cp0_exception(cp0_exception),
    .cp0_excode(cp0_excode),
    .cp0_exc_pc(cp0_exc_pc),
    .cp0_mem_vaddr(cp0_mem_vaddr),
    .cp0_exc_ds(cp0_exc_ds),
    .cp0_result(cp0_result),
    .cp0_EBASE(cp0_EBASE),
    .cp0_SR(cp0_SR),
    
    // jump forward
    .clear_out(clear),
    .pc_jump(),
    .pc_jump_addr(pc_jump_addr)  
);

/* ========= CP0 ========= */
wire[31:0]  cp0_COUNTER;
wire[31:0]  cp0_COMPARE;
wire[5:0]   ip_7_2;



cp0 cp0_instance (
    .clk(clk_50M),
    .rst(reset_btn),
    
    .cp0_entryhi(cp0_ENTRYHI),
    .cp0_ebase(cp0_EBASE),
    .cp0_status(cp0_SR),
    .cp0_counter(cp0_COUNTER),
    .cp0_compare(cp0_COMPARE),
    
    .cp0_ce(cp0_ce),
    .cp0_inst(cp0_inst),
    .cp0_reg(cp0_reg),
    .cp0_putval(cp0_putval),
    .cp0_result(cp0_result),
    
    .cp0_exception(cp0_exception),
    .cp0_excode(cp0_excode),
    .cp0_exc_pc(cp0_exc_pc),
    .cp0_mem_vaddr(cp0_mem_vaddr),
    .cp0_exc_ds(cp0_exc_ds),
    
    // Interrupt
    .ip_7_2(ip_7_2),
    
    // TLBR
    .tlbr_qe(tlbr_qe),
    .tlbr_index(tlbr_index),
    .tlbr_result(tlbr_result),
    
    // TLBP
    .tlbp_qe(tlbp_qe),
    .tlbp_result(tlbp_result),
    
    // TLB 修改
    .tlb_we(tlb_we),
    .tlb_write_index(tlb_write_index),
    .tlb_write_entry(tlb_write_entry)    // { EntryHi, EntryLo0, EntryLo1 }
);


// PLL分频示例
wire locked, clk_10M, clk_20M;
pll_example clock_gen 
 (
  // Clock out ports
  .clk_out1(clk_10M), // 时钟输出1，频率在IP配置界面中设置
  .clk_out2(clk_20M), // 时钟输出2，频率在IP配置界面中设置
  // Status and control signals
  .reset(reset_btn), // PLL复位输入
  .locked(locked), // 锁定输出，"1"表示时钟稳定，可作为后级电路复位
 // Clock in ports
  .clk_in1(clk_50M) // 外部时钟输入
 );



// 数码管连接关系示意图，dpy1同理
// p=dpy0[0] // ---a---
// c=dpy0[1] // |     |
// d=dpy0[2] // f     b
// e=dpy0[3] // |     |
// b=dpy0[4] // ---g---
// a=dpy0[5] // |     |
// f=dpy0[6] // e     c
// g=dpy0[7] // |     |
//           // ---d---  p





//图像输出演示，分辨率800x600@75Hz，像素时钟为50MHz
wire [11:0] hdata;
assign video_red = hdata < 266 ? 3'b111 : 0; //红色竖条
assign video_green = hdata < 532 && hdata >= 266 ? 3'b111 : 0; //绿色竖条
assign video_blue = hdata >= 532 ? 2'b11 : 0; //蓝色竖条
assign video_clk = clk_50M;
vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at75 (
    .clk(clk_50M), 
    .hdata(hdata), //横坐标
    .vdata(),      //纵坐标
    .hsync(video_hsync),
    .vsync(video_vsync),
    .data_enable(video_de)
);
/* =========== Demo code end =========== */

endmodule
