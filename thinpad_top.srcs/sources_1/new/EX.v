`define RI_EXC begin ex_cause <= ~ex_stop ? 5'd10 : 5'd0; bubble_cnt <= bubble_cnt_dec; ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010; if_forward_reg_write <= 1'b0; if_pc_jump <= ~ex_stop; exception <= ~ex_stop; pc_jumpto <= EX_ADDR_INIT; end

module EX(
    input wire clk,
    input wire rst,

    input wire[5:0] op,
    input wire[5:0] func,
    input wire ex_stop,
    input wire[31:0] data_a,
    input wire[31:0] data_b,
    input wire[31:0] simm,
    input wire[31:0] zimm,
    input wire[31:0] npc,
    input wire[25:0] jpc,
    
    output reg last_eret,
    
    //ex
    input wire if_dealing_ex,
    input wire[4:0] ip_6_2,
    
    // multiplier
    input wire[63:0] mpresultu,
    input wire[63:0] mpresults,
    
    //TLB
    input wire[66:0]    tlb_status, // { is_store, is_IF, is_miss, rollback-epc, bva }
    input wire          if_tlb_miss,
    output reg[31:0]    tlb_rollback_pc,
    output reg          tlb_write,
    output reg[3:0]     tlb_write_idx,
    output reg[95:0]    tlb_write_entry,
    output reg[7:0]     current_asid,
        
    output reg[31:0] result,
    output reg[31:0] mem_data,
    output reg if_pc_jump,
    output reg[31:0] pc_jumpto,
    output reg[4:0] load_byte,
    
    input wire[2:0] bubble_cnt_last,
    input wire[2:0] ex_stopcnt_last,
    output reg[2:0] bubble_cnt,
    output reg[2:0] ex_stopcnt,
    output wire delay_slot,
    output reg exception,
    
    output reg if_forward_reg_write,
    
    // pass
    input wire if_reg_write_i,
    output reg if_reg_write_o,
    input wire if_mem_read_i,
    output reg if_mem_read_o,
    input wire if_mem_write_i,
    output reg if_mem_write_o,
    input wire[4:0] data_write_reg_i,
    output reg[4:0] data_write_reg_o,
    
    // TLBP. TLBR
    input wire[4:0] tlb_query_idx,
    input wire[95:0] tlb_query_entry,
    output reg tlbp_query,
    output reg tlbr_query
    );

wire[3:0] ffclo[0:31];
assign ffclo[0] = 0; assign ffclo[1] = 0; assign ffclo[2] = 0; assign ffclo[3] = 0;
assign ffclo[4] = 0; assign ffclo[5] = 0; assign ffclo[6] = 0; assign ffclo[7] = 0;
assign ffclo[8] = 1; assign ffclo[9] = 1; assign ffclo[10] = 1; assign ffclo[11] = 1;
assign ffclo[12] = 2; assign ffclo[13] = 2; assign ffclo[14] = 3; assign ffclo[15] = 4;

wire[3:0] ffclz[0:31];
assign ffclz[0] = 4; assign ffclz[1] = 3; assign ffclz[2] = 2; assign ffclz[3] = 2;
assign ffclz[4] = 1; assign ffclz[5] = 1; assign ffclz[6] = 1; assign ffclz[7] = 1;
assign ffclz[8] = 0; assign ffclz[9] = 0; assign ffclz[10] = 0; assign ffclz[11] = 0;
assign ffclz[12] = 0; assign ffclz[13] = 0; assign ffclz[14] = 0; assign ffclz[15] = 0;

reg[2:0] bubble_cnt_dec, ex_stopcnt_dec;

reg last_ds, if_b_njump;
assign delay_slot = if_pc_jump;
wire delay_slot_n = if_b_njump;

parameter EX_ADDR_INC = 12'h180;

parameter INDEX = 0;        // Index
parameter RANDOM = 1;       // Random
parameter ENTRYL0 = 2;      // EntryLo0
parameter ENTRYL1 = 3;      // EntryLo1
parameter PAGEMASK = 5;     // PageMask
parameter BVA = 8;          // BadVAddr
parameter COUNT = 9;        // Counter
parameter ENTRYHI = 10;     // EntryHi
parameter COMPARE = 11;     // Compare
parameter STATUS = 12;      // SR
parameter CAUSE = 13;       // Cause
parameter EPC = 14;         // EPC
parameter EBASE = 15;         // ExceptionBase
(* DONT_TOUCH = "yes" *) reg [31:0] hi, lo, cp0[0:31];
wire[31:0] sl_addr = data_a + simm;
wire[31:0] EX_ADDR_INIT = (cp0[EBASE] + EX_ADDR_INC);

reg[5:0] ex_cause;
reg [31:0] bad_addr;

wire[32:0] ext_data_a = {data_a[31], data_a};
wire[32:0] ext_data_b = {data_b[31], data_b};
wire[32:0] ext_simm = {simm[31], simm};
wire[32:0] ext_add = ext_data_a + ext_data_b;
wire[32:0] ext_sub = ext_data_a - ext_data_b;
wire[32:0] ext_addsimm = ext_data_a + ext_simm;

reg intq;
reg timer_int;

wire[5:0] ip_7_2 = { timer_int, ip_6_2 };

always @(*) begin
    // passes
    if_reg_write_o <= ex_stop ? 1'b0 : if_reg_write_i;
    if_mem_read_o <= ex_stop ? 1'b0 : if_mem_read_i; // don't R/W if in bubble
    if_mem_write_o <= ex_stop ? 1'b0 : if_mem_write_i;
    data_write_reg_o <= data_write_reg_i;
    
    bubble_cnt_dec = bubble_cnt_last ? bubble_cnt_last - 3'b001 : 3'b000;
    ex_stopcnt_dec = ex_stopcnt_last ? ex_stopcnt_last - 3'b001 : 3'b000;
    
    mem_data <= data_b;
    
    result <= 32'h00000000; // avoid latches
    pc_jumpto <= 32'h00000000; // avoid latches
    load_byte <= 5'b01111;
    if_b_njump <= 1'b0;
    
    exception <= 1'b0;
    ex_cause <= 5'b00000;
    bad_addr <= 32'h00000000;
    tlb_rollback_pc <= npc - (last_ds ?  32'd8 : 32'd4);
    
    tlb_write <= 1'b0;
    
    tlbp_query <= 1'b0;
    tlbr_query <= 1'b0;
    
    last_eret <= 1'b0;
    
    // ALU
    if (intq) begin
        ex_cause <= 5'd0;
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
        if_forward_reg_write <= 1'b0;
        if_pc_jump <= ~ex_stop;
        exception <= ~ex_stop;
        pc_jumpto <= EX_ADDR_INIT;
    end
    else if (tlb_status[65:64] == 2'b01) begin  // TLB miss && data
        ex_cause <=  tlb_status[66] ? 5'd3 : 5'd2;
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= 3'b010;
        if_forward_reg_write <= 1'b0;
        if_pc_jump <= 1'b1;
        exception <= 1'b1;  // force jump
        pc_jumpto <= cp0[EBASE];    // TLB refill exception handle, at CP0[EBASE]
    end
    else if (if_tlb_miss) begin
        ex_cause <= 5'd2;
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= 3'b010;
        if_forward_reg_write <= 1'b0;
        if_pc_jump <= 1'b1;
        exception <= 1'b1;  // force jump
        pc_jumpto <= cp0[EBASE];    // TLB refill exception handle, at CP0[EBASE]
    end
    else case (op)
    6'b000000: begin
        // SPECIAL
        case (func)
        6'b100000: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // ADD
            if (ext_add[32] == ext_add[31]) begin
                result <= data_a + data_b;
                bubble_cnt <= bubble_cnt_dec;
                ex_stopcnt <= ex_stopcnt_dec;
                if_forward_reg_write <= ~ex_stop;
                if_pc_jump <= 1'b0;
            end
            else begin
                // exception 算术溢出
                ex_cause <= ~ex_stop ? 5'd12 : 5'd0;
                bubble_cnt <= bubble_cnt_dec;
                ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
                if_forward_reg_write <= 1'b0;
                if_pc_jump <= ~ex_stop;
                exception <= ~ex_stop;
                pc_jumpto <= EX_ADDR_INIT;
            end
        end
        
        6'b100001: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // ADDU
            result <= data_a + data_b;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b100010: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // SUB
            if (ext_sub[32] == ext_sub[31]) begin
                result <= data_a - data_b;
                bubble_cnt <= bubble_cnt_dec;
                ex_stopcnt <= ex_stopcnt_dec;
                if_forward_reg_write <= ~ex_stop;
                if_pc_jump <= 1'b0;
            end
            else begin
                // exception 算术溢出
                ex_cause <= ~ex_stop ? 5'd12 : 5'd0;
                bubble_cnt <= bubble_cnt_dec;
                ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
                if_forward_reg_write <= 1'b0;
                if_pc_jump <= ~ex_stop;
                exception <= ~ex_stop;
                pc_jumpto <= EX_ADDR_INIT;
            end
        end
        
        6'b100011: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // SUBU
            result <= data_a - data_b;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b100100: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // AND
            result <= data_a & data_b;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b100101: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // OR
            result <= data_a | data_b;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b100110: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // XOR
            result <= data_a ^ data_b;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b100111: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // NOR
            result <= ~(data_a | data_b);
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b000000: if (jpc[25:21] != 5'b00000) `RI_EXC else begin
        // SLL
            result <= data_b << zimm[10:6];
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end

        6'b000100: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // SLLV
            result <= data_b << data_a[4:0];
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b000010: if (jpc[25:21] != 5'b00000) `RI_EXC else begin
        // SRL
            result <= data_b >> zimm[10:6];
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b000110: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // SRLV
            result <= data_b >> data_a[4:0];
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b000011: if (jpc[25:21] != 5'b00000) `RI_EXC else begin
        // SRA
            result <= ($signed(data_b)) >>> zimm[10:6];
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b000111: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // SRAV
            result <= ($signed(data_b)) >>> data_a[4:0];
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b101010: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // SLT
            result <= ($signed(data_a) < $signed(data_b));
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b101011: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // SLTU
            result <= data_a < data_b ? 32'h00000001 : 32'h00000000;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b001000: if (jpc[20:11] != 10'b0000000000) `RI_EXC else begin
        // JR
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
            pc_jumpto <= data_a;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= ~ex_stop;
        end
        
        6'b001001: if (jpc[20:16] != 5'b00000) `RI_EXC else begin
        // JALR
            result <= npc + 32'd4;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
            pc_jumpto <= data_a;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= ~ex_stop;
        end
        
        6'b010000: if (jpc[10:6] != 5'b00000 || jpc[25:16] != 10'b0000000000) `RI_EXC else begin
        // MFHI
            result <= hi;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b010010: if (jpc[10:6] != 5'b00000 || jpc[25:16] != 10'b0000000000) `RI_EXC else begin
        // MFLO
            result <= lo;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b010011, 6'b010001: if (jpc[20:6] != 15'b00000000000000) `RI_EXC else begin
        // MTLO, MTHI
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= 1'b0;
        end
        
        6'b001100: begin
        // SYSCALL
            ex_cause <= ~ex_stop ? 5'd8 : 5'd0;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= ~ex_stop;
            exception <= ~ex_stop;
            pc_jumpto <= EX_ADDR_INIT;
        end
        
        6'b001101: begin
        // BREAK
            ex_cause <= ~ex_stop ? 5'd9 : 5'd0;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= ~ex_stop;
            exception <= ~ex_stop;
            pc_jumpto <= EX_ADDR_INIT;
        end
        
        6'b001010: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // MOVZ
            result <= data_a;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop & (data_b == 32'h00000000);
            if_pc_jump <= 1'b0;
        end
        
        6'b011001: if (jpc[15:6] != 10'b0000000000) `RI_EXC else begin
            // MULTU
            // data_a * data_b
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= 1'b0;
        end
        
        6'b011000: if (jpc[15:6] != 10'b0000000000) `RI_EXC else begin
            // MULT
            // data_a * data_b
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= 1'b0;
        end
        
        default: `RI_EXC
        endcase
    end
    
    6'b011100: begin
    // SPECIAL2
        case (func)
        6'b100000: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // CLZ
            result <= ((data_a[31:16] == 16'h0000)
                ? (5'd16 + ((data_a[15:8] == 8'h00)
                    ? (4'd8 + (data_a[7:4] == 4'h0)
                        ? 3'd4 + ffclz[data_a[3:0]]
                        : ffclz[data_a[7:4]])
                    : ((data_a[15:12] == 4'h0)
                        ? 3'd4 + ffclz[data_a[11:8]]
                        : ffclz[data_a[15:12]])))
                : ((data_a[31:24] == 8'h00)
                    ? (4'd8 + ((data_a[23:20] == 4'h0)
                        ? 3'd4 + ffclz[data_a[19:16]]
                        : ffclz[data_a[23:20]]))
                    : ((data_a[31:28] == 4'h0)
                        ? 3'd4 + ffclz[data_a[27:24]]
                        : ffclz[data_a[31:28]])));
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        6'b100001: if (jpc[10:6] != 5'b00000) `RI_EXC else begin
        // CLO
            result <= ((data_a[31:16] == 16'hFFFF)
                ? (5'd16 + ((data_a[15:8] == 8'hFF)
                    ? (4'd8 + (data_a[7:4] == 4'hF)
                        ? 3'd4 + ffclo[data_a[3:0]]
                        : ffclo[data_a[7:4]])
                    : ((data_a[15:12] == 4'hF)
                        ? 3'd4 + ffclo[data_a[11:8]]
                        : ffclo[data_a[15:12]])))
                : ((data_a[31:24] == 8'hFF)
                    ? (4'd8 + ((data_a[23:20] == 4'hF)
                        ? 3'd4 + ffclo[data_a[19:16]]
                        : ffclo[data_a[23:20]]))
                    : ((data_a[31:28] == 4'hF)
                        ? 3'd4 + ffclo[data_a[27:24]]
                        : ffclo[data_a[31:28]])));
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_forward_reg_write <= ~ex_stop;
            if_pc_jump <= 1'b0;
        end
        
        default: `RI_EXC
        endcase
    end
    
    6'b010000: begin
        // COP0
        case (jpc[25:21])
        5'b00100: if (jpc[10:3] != 8'b00000000) `RI_EXC else begin
            //MTC0
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_pc_jump <= 1'b0;
            if_forward_reg_write <= 1'b0;
        end
        5'b00000: if (jpc[10:3] != 8'b00000000) `RI_EXC else begin
            // MFC0
            result <= cp0[jpc[15:11]];
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_pc_jump <= 1'b0;
            if_forward_reg_write <= ~ex_stop;
        end
        5'b10000: begin
            if (jpc == 26'b10000000000000000000011000) begin
            // ERET
                bubble_cnt <= bubble_cnt_dec;
                ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
                if_forward_reg_write <= 1'b0;
                if_pc_jump <= ~ex_stop;
                pc_jumpto <= {cp0[EPC][31:2], 2'b00}; // <<2
                
                last_eret <= 1'b1;
            end
            else if (jpc == 26'b10000000000000000000000010) begin
                // TLBWI
                tlb_write <= 1'b1;
                tlb_write_idx <= cp0[INDEX]; 
                tlb_write_entry <= { cp0[ENTRYHI], cp0[ENTRYL0], cp0[ENTRYL1] };
                
                bubble_cnt <= bubble_cnt_dec;
                ex_stopcnt <= ex_stopcnt_dec;
                if_pc_jump <= 1'b0;
                if_forward_reg_write <= 1'b0;
            end
            else if (jpc == 26'b10000000000000000000000110) begin
                // TLBWR
                tlb_write <= 1'b1;
                tlb_write_idx <= cp0[RANDOM]; 
                tlb_write_entry <= { cp0[ENTRYHI], cp0[ENTRYL0], cp0[ENTRYL1] };
                
                bubble_cnt <= bubble_cnt_dec;
                ex_stopcnt <= ex_stopcnt_dec;
                if_pc_jump <= 1'b0;
                if_forward_reg_write <= 1'b0;
            end
            else if (jpc == 26'b10000000000000000000001000) begin
                // TLBP
                tlbp_query <= 1'b1;
                tlb_write_entry <= { cp0[ENTRYHI], cp0[ENTRYL0], cp0[ENTRYL1] };
                
                bubble_cnt <= bubble_cnt_dec;
                ex_stopcnt <= ex_stopcnt_dec;
                if_pc_jump <= 1'b0;
                if_forward_reg_write <= 1'b0;
            end
            else if (jpc == 26'b10000000000000000000000001) begin
                // TLBR
                tlbr_query <= 1'b1;
                tlb_write_idx <= cp0[INDEX];
                
                bubble_cnt <= bubble_cnt_dec;
                ex_stopcnt <= ex_stopcnt_dec;
                if_pc_jump <= 1'b0;
                if_forward_reg_write <= 1'b0;
            end
            else `RI_EXC
        end
        default: `RI_EXC
        endcase
    end
    
    6'b001000: begin
        // ADDI
        if (ext_addsimm[32] == ext_addsimm[31]) begin
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stopcnt_dec;
            if_pc_jump <= 1'b0;
            result <= data_a + simm;
            if_forward_reg_write <= ~ex_stop;
        end
        else begin
            // exception 算术溢出
            ex_cause <= ~ex_stop ? 5'd12 : 5'd0;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= ~ex_stop;
            exception <= ~ex_stop;
            pc_jumpto <= EX_ADDR_INIT;
        end
    end
    
    6'b001001: begin
        // ADDIU
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stopcnt_dec;
        if_pc_jump <= 1'b0;
        result <= data_a + simm;
        if_forward_reg_write <= ~ex_stop;
    end
    
    6'b001100: begin
        // ANDI
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stopcnt_dec;
        if_pc_jump <= 1'b0;
        result <= data_a & zimm;
        if_forward_reg_write <= ~ex_stop;
    end
    
    6'b001101: begin
        // ORI
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stopcnt_dec;
        if_pc_jump <= 1'b0;
        result <= data_a | zimm;
        if_forward_reg_write <= ~ex_stop;
    end
    
    6'b001110: begin
        // XORI
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stopcnt_dec;
        if_pc_jump <= 1'b0;
        result <= data_a ^ zimm;
        if_forward_reg_write <= ~ex_stop;
    end
    
    6'b001010: begin
        // SLTI
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stopcnt_dec;
        if_pc_jump <= 1'b0;
        result <= ($signed(data_a) < $signed(simm));
        if_forward_reg_write <= ~ex_stop;
    end
    
    6'b001011: begin
        // SLTIU
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stopcnt_dec;
        if_pc_jump <= 1'b0;
        result <= data_a < simm ? 32'h00000001 : 32'h00000000;
        if_forward_reg_write <= ~ex_stop;
    end
    
    6'b001111: if (jpc[25:21] != 5'b00000) `RI_EXC else begin
        // LUI
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stopcnt_dec;
        if_pc_jump <= 1'b0;
        result <= (zimm << 16);
        if_forward_reg_write <= ~ex_stop;
    end
    
    6'b000010: begin
        // J
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
        if_pc_jump <= ~ex_stop;
        pc_jumpto <= {npc[31:28], jpc, 2'b00}; // <<2
        if_forward_reg_write <= 1'b0;
    end
    
    6'b000011: begin
        // JAL
        result <= npc + 32'd4;
        bubble_cnt <= bubble_cnt_dec;
        ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
        if_pc_jump <= ~ex_stop;
        pc_jumpto <= {npc[31:28], jpc, 2'b00}; // <<2
        if_forward_reg_write <= ~ex_stop;
    end
            
    6'b000100: begin
        // BEQ
        bubble_cnt <= bubble_cnt_dec;
        pc_jumpto <= npc + {simm[29:0], 2'b00};
        if_forward_reg_write <= 1'b0;
        if (data_a == data_b) begin
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010; // clear backward
            if_pc_jump <= ~ex_stop;
            if_b_njump <= 1'b0;
        end
        else begin
            ex_stopcnt <= ex_stopcnt_dec; // dont stap
            if_pc_jump <= 1'b0;
            if_b_njump <= ~ex_stop;
        end
    end
    
    6'b000101: begin
        // BNE
        bubble_cnt <= bubble_cnt_dec;
        pc_jumpto <= npc + {simm[29:0], 2'b00};
        if_forward_reg_write <= 1'b0;
        if (data_a != data_b) begin
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010; // clear backward
            if_pc_jump <= ~ex_stop;
            if_b_njump <= 1'b0;
        end
        else begin
            ex_stopcnt <= ex_stopcnt_dec; // dont stap
            if_pc_jump <= 1'b0;
            if_b_njump <= ~ex_stop;
        end
    end
    
    6'b000111: if (jpc[20:16] != 5'b00000) `RI_EXC else begin
        // BGTZ
        bubble_cnt <= bubble_cnt_dec;
        pc_jumpto <= npc + {simm[29:0], 2'b00};
        if_forward_reg_write <= 1'b0;
        if ($signed(data_a) > $signed(data_b)) begin // signed(A) > signed(B)
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010; // clear backward
            if_pc_jump <= ~ex_stop;
            if_b_njump <= 1'b0;
        end
        else begin
            ex_stopcnt <= ex_stopcnt_dec; // dont stap
            if_pc_jump <= 1'b0;
            if_b_njump <= ~ex_stop;
        end
    end
    
    6'b000110: if (jpc[20:16] != 5'b00000) `RI_EXC else begin
        // BLEZ
        bubble_cnt <= bubble_cnt_dec;
        pc_jumpto <= npc + {simm[29:0], 2'b00};
        if_forward_reg_write <= 1'b0;
        if ($signed(data_a) <= $signed(data_b)) begin // signed(A) <= signed(B)
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010; // clear backward
            if_pc_jump <= ~ex_stop;
            if_b_njump <= 1'b0;
        end
        else begin
            ex_stopcnt <= ex_stopcnt_dec; // dont stap
            if_pc_jump <= 1'b0;
            if_b_njump <= ~ex_stop;
        end
    end
    
    6'b000001: begin
        // REGIMM
        bubble_cnt <= bubble_cnt_dec;
        pc_jumpto <= npc + {simm[29:0], 2'b00};
        result <= npc + 32'd4;
        case (jpc[20:16]) // ins[20:16]
        5'b00000, 5'b10000: begin
            // BLTZ(AL)
            if_forward_reg_write <= (~ex_stop) & jpc[20];
            if (data_a[31]) begin // signed(A) < 0
                ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010; // clear backward
                if_pc_jump <= ~ex_stop;
                if_b_njump <= 1'b0;
            end
            else begin
                ex_stopcnt <= ex_stopcnt_dec; // dont stap
                if_pc_jump <= 1'b0;
                if_b_njump <= ~ex_stop;
            end
        end
        5'b00001, 5'b10001: begin
            // BGEZ(AL)
            if_forward_reg_write <= (~ex_stop) & jpc[20];
            if (~data_a[31]) begin // signed(A) >= 0
                ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010; // clear backward
                if_pc_jump <= ~ex_stop;
                if_b_njump <= 1'b0;
            end
            else begin
                ex_stopcnt <= ex_stopcnt_dec; // dont stap
                if_pc_jump <= 1'b0;
                if_b_njump <= ~ex_stop;
            end
        end
        default: `RI_EXC
        endcase
    end
    
    6'b100011: begin
        // LW
        if (sl_addr[1:0] == 2'b00) begin
            result <= sl_addr;
            bubble_cnt <= ex_stop ? bubble_cnt_dec : 3'b001; // IF/ID/EX stop
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b001; // R/W conflict
            if_pc_jump <= 1'b0;
            if_forward_reg_write <= 1'b0;
        end
        else begin
            // exception 读取非对齐
            ex_cause <= ~ex_stop ? 5'd4 : 5'd0;
            bad_addr <= sl_addr;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= ~ex_stop;
            exception <= ~ex_stop;
            pc_jumpto <= EX_ADDR_INIT;
        end
    end
    
    6'b100001, 6'b100101: begin
        // LH LHU
        if (sl_addr[0] == 1'b0) begin
            load_byte <= {op[2], sl_addr[1], sl_addr[1], ~sl_addr[1], ~sl_addr[1]};
            result <= sl_addr;
            bubble_cnt <= ex_stop ? bubble_cnt_dec : 3'b001; // IF/ID/EX stop
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b001; // R/W conflict
            if_pc_jump <= 1'b0;
            if_forward_reg_write <= 1'b0;
        end
        else begin
            // exception 读取非对齐
            ex_cause <= ~ex_stop ? 5'd4 : 5'd0;
            bad_addr <= sl_addr;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= ~ex_stop;
            exception <= ~ex_stop;
            pc_jumpto <= EX_ADDR_INIT;
        end
    end
    
    6'b100000, 6'b100100: begin
        // LB LBU
        load_byte <= {op[2],
            sl_addr[1] & sl_addr[0], sl_addr[1] & ~sl_addr[0],
            ~sl_addr[1] & sl_addr[0], ~sl_addr[1] & ~sl_addr[0]};
        result <= sl_addr;
        bubble_cnt <= ex_stop ? bubble_cnt_dec : (sl_addr == 32'hBFD003F8 ? 3'b111 : 3'b001); // IF/ID/EX stop
        ex_stopcnt <= ex_stop ? ex_stopcnt_dec : (sl_addr == 32'hBFD003F8 ? 3'b111 : 3'b001); // R/W conflict
        if_pc_jump <= 1'b0;
        if_forward_reg_write <= 1'b0;
    end
    
    6'b101011: begin
        // SW
        if (sl_addr[1:0] == 2'b00) begin
            result <= sl_addr;
            mem_data <= data_b; // write mem
            bubble_cnt <= ex_stop ? bubble_cnt_dec : 3'b001; // IF/ID/EX stop
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b001;
            if_pc_jump <= 1'b0;
            if_forward_reg_write <= 1'b0;
        end
        else begin
            // exception 写入非对齐
            ex_cause <= ~ex_stop ? 5'd5 : 5'd0;
            bad_addr <= sl_addr;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= ~ex_stop;
            exception <= ~ex_stop;
            pc_jumpto <= EX_ADDR_INIT;
        end
    end
    
    6'b101001: begin
        // SH
        if (sl_addr[0] == 1'b0) begin
            load_byte <= {1'b0, sl_addr[1], sl_addr[1], ~sl_addr[1], ~sl_addr[1]};
            result <= sl_addr;
            mem_data <= data_b; // write mem
            bubble_cnt <= ex_stop ? bubble_cnt_dec : (sl_addr == 32'hBFD003F8 ? 3'b111 : 3'b001); // IF/ID/EX stop
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : (sl_addr == 32'hBFD003F8 ? 3'b111 : 3'b001); // R/W conflict
            if_pc_jump <= 1'b0;
            if_forward_reg_write <= 1'b0;
        end
        else begin
            // exception 写入非对齐
            ex_cause <= ~ex_stop ? 5'd5 : 5'd0;
            bad_addr <= sl_addr;
            bubble_cnt <= bubble_cnt_dec;
            ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b010;
            if_forward_reg_write <= 1'b0;
            if_pc_jump <= ~ex_stop;
            exception <= ~ex_stop;
            pc_jumpto <= EX_ADDR_INIT;
        end
    end
    
    6'b101000: begin
        // SB
        load_byte <= {1'b0,
            sl_addr[1] & sl_addr[0], sl_addr[1] & ~sl_addr[0],
            ~sl_addr[1] & sl_addr[0], ~sl_addr[1] & ~sl_addr[0]};
        result <= sl_addr;
        mem_data <= data_b; // write mem
        bubble_cnt <= ex_stop ? bubble_cnt_dec : 3'b001; // IF/ID/EX stop
        ex_stopcnt <= ex_stop ? ex_stopcnt_dec : 3'b001;
        if_pc_jump <= 1'b0;
        if_forward_reg_write <= 1'b0;
    end

    default: `RI_EXC
    endcase
end

always@(posedge clk or negedge rst) begin
    if (ip_7_2[2] == 1'b1) begin    // IP4 = 1
        intq <= cp0[STATUS][0] == 1 // IE = 1
            && cp0[STATUS][12] == 1 // IM4 = 1
            && cp0[STATUS][1] == 0; // EXL = normal
    end 
    else if (ip_7_2[5] == 1'b1) begin // IP7 = 1
        intq <= cp0[STATUS][0] == 1 // IE = 1
            && cp0[STATUS][15] == 1 // IM7 = 1
            && cp0[STATUS][1] == 0; // EXL = normal
    end
    else begin
        intq <= 0;
    end
    if (!rst) begin
        hi <= 32'b0;
        lo <= 32'b0;
        cp0[0] <= 32'b0;
        cp0[1] <= 32'b0;
        cp0[2] <= 32'b0;
        cp0[3] <= 32'b0;
        cp0[4] <= 32'b0;
        cp0[5] <= 32'b0;
        cp0[6] <= 32'b0;
        cp0[7] <= 32'b0;
        cp0[8] <= 32'b0;
        cp0[9] <= 32'b0;    // count
        cp0[10] <= 32'b0;   
        cp0[11] <= 32'b0;   // compare
        cp0[12] <= 32'b0; // status
        cp0[13] <= 32'h00000001; // cause
        cp0[14] <= 32'b0; // epc
        cp0[15] <= 32'h80001000; // ebase
        cp0[16] <= 32'b0;
        cp0[17] <= 32'b0;
        cp0[18] <= 32'b0;
        cp0[19] <= 32'b0;
        cp0[20] <= 32'b0;
        cp0[21] <= 32'b0;
        cp0[22] <= 32'b0;
        cp0[23] <= 32'b0;
        cp0[24] <= 32'b0;
        cp0[25] <= 32'b0;
        cp0[26] <= 32'b0;
        cp0[27] <= 32'b0;
        cp0[28] <= 32'b0;
        cp0[29] <= 32'b0;
        cp0[30] <= 32'b0;
        cp0[31] <= 32'b0;
        timer_int <= 1'b0;
    end
    else begin 
        if (exception) begin
            cp0[CAUSE][15:10] <= ip_7_2;
            cp0[CAUSE][6:2] <= ex_cause; // cause: ExcCode
            if (cp0[STATUS][1] == 1'b0) begin
                cp0[CAUSE][31] <= last_ds; // cause:BD
                cp0[STATUS][1] <= 1; // status:EXL
                if (tlb_status[65:64] == 2'b01) begin    // TLB exception && not IF
                    cp0[EPC] <= tlb_status[63:32];
                end
                else begin
                    cp0[EPC] <= npc - (last_ds ?  32'd8 : 32'd4); // EPC
                end
                // TODO cause:IP4
            end
            if (ex_cause == 5'd4 || ex_cause == 5'd5)
                cp0[BVA] <= bad_addr; // BVA
            else if (ex_cause == 5'd2 || ex_cause == 5'd3) begin
                if (tlb_status[65:64] == 2'b01) // Memory Access
                    cp0[BVA] <= tlb_status[31:0]; // BVA
                else
                    cp0[BVA] <= npc - (last_ds ?  32'd8 : 32'd4); // BVA = EPC
            end
        end
        else if(~ex_stop) begin
            case (op)
            6'b000000:
                case (func)
                6'b010001: hi <= data_a;
                6'b010011: lo <= data_a;
                6'b011001: begin
                    hi <= mpresultu[63:32];
                    lo <= mpresultu[31:0];
                end
                6'b011000: begin
                    hi <= mpresults[63:32];
                    lo <= mpresults[31:0];
                end
                endcase
            6'b010000: begin
                if (jpc[25:21] == 5'b00100) begin // MTC0
                    cp0[jpc[15:11]] <= data_b;
                end
                else if (func == 6'b011000) begin// ERET
                    cp0[STATUS][1] <= 0; // status:EXL
                end
                else if (jpc == 26'b10000000000000000000001000) begin
                    // TLBP
                    cp0[INDEX] <= {tlb_query_idx[4], 27'b0, tlb_query_idx[3:0]};
                end
                else if (jpc == 26'b10000000000000000000000001) begin
                    // TLBR
                    cp0[ENTRYHI] <= tlb_query_entry[95:64];
                    cp0[ENTRYL0] <= tlb_query_entry[63:32];
                    cp0[ENTRYL1] <= tlb_query_entry[31: 0];
                end
            end
            endcase
            
            if ((op == 6'b010000) && (jpc[25:21] == 5'b00100) && (jpc[15:11] == 5'd9)) begin // set cp0[COUNT]
                timer_int <= (data_b >= cp0[COMPARE]);
            end
            else begin
                if (cp0[COUNT] < cp0[COMPARE]) begin
                    timer_int <= 1'b0;
                    cp0[COUNT] <= cp0[COUNT] + 1;
                end
                else begin
                    timer_int <= 1'b1;
                end
            end
        end
        
        cp0[RANDOM] <= {28'b0, cp0[RANDOM][3:0] + 1};
        current_asid <= cp0[ENTRYHI][7:0];
        last_ds <= delay_slot | delay_slot_n;
    end
end

endmodule
