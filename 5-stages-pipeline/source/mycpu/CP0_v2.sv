`include "common.svh"
`include "Myheadfile.svh"

module CP0(
    input i1 clk, resetn,
    input i32 cp0_data2w, invalid_addr, excPC,  
    input i5 cp0_idx,
    input i1 cp0_write, exception, isBadAddr, inDelaySlot, ERET2pc,
    (*mark_debug = "true"*)input i6 ext_int, m_excCode,

    (*mark_debug = "true"*)output i32 cp0_val, cp0_epc, 
    (*mark_debug = "true"*)output i1 interrupt
);
//variable defination    
    typedef struct packed {
        i1      BD;       // 31: in branch delay slot?
        i1      TI;       // 30: timer interrupt, in Release 2
        i2      CE;       // [29:28]: coprocessor unit number
        i1      DC;       // 27: optional
        i1      PCI;      // 26: performance counter interrupt, in Release 2
        i2      ASE1;     // [25:24]: reserved
        i1      IV;       // 23: interrupt vector
        i1      WP;       // 22: optional
        i1      FDCI;     // 21: optional
        i5      RES1;     // [20:16]: reserved
        i8      IP;       // [15:8]: interrupt requests
        i1      RES2;     // 7: reserved
        i5      ExcCode;  // [6:2]: exception code
        i2      RES3;     // [1:0]: reserved
    } Cause_t;

    typedef struct packed {
        i4 CU;    // [31:28]: access to coprocessors
        i1 RP;    // 27: optional
        i1 FR;    // 26: floating point registers, optional
        i1 RE;    // 25: optional
        i1 MX;    // 24: optional
        i1 RES1;  // 23: reserved
        i1 BEV;   // 22: location of exception vectors
        i1 TS;    // 21: optional
        i1 SR;    // 20: optional
        i1 NMI;   // 19: optional
        i1 ASE;   // 18: optional
        i2 RES2;  // [17:16]: reserved
        i8 IM;    // [15:8]: interrupt masks IM7~IM0
        i3 RES3;  // [7:5]: reserved
        i2 KSU;   // [4:3]: supervisor mode, optional
        i1 ERL;   // 2: error level
        i1 EXL;   // 1: exception level
        i1 IE;    // 0: interrupt enable
    } Status_t;
    
    parameter Status_t CP0_STATUS_RESET = '{
        CU  : 4'b0001,
        BEV : 1'b1,
        ERL : 1'b1,
    
        default: '0
    };
    
    parameter Status_t CP0_STATUS_MASK = '{
        CU  : 4'b0001,  // CU0 is writable, although it's ignored.
        BEV : 1'b1,
        IM  : 8'hff,
        ERL : 1'b1,
        EXL : 1'b1,
        IE  : 1'b1,
    
        default: '0
    };

    i1 clock_count;
    i1 timer_interrupt, timer_interrupt_nxt;
    i32 BadVAddr, BadVAddr_nxt;
    i32 Count, Count_nxt;
    i32 Compare, Compare_nxt;
    i32 EPC, EPC_nxt;

    Status_t Status, Status_nxt;
    Cause_t Cause, Cause_nxt;

    always_ff @(posedge clk) begin
        if(~resetn)begin
            {BadVAddr, Count, Cause, Compare ,EPC} <= '0;
            Status <= CP0_STATUS_RESET;
            clock_count <= '0;
            timer_interrupt <= '0;
        end else begin
            BadVAddr <= BadVAddr_nxt;
            Count <= Count_nxt;
            Compare <= Compare_nxt;
            Status <= Status_nxt;
            Cause <= Cause_nxt;
            EPC <= EPC_nxt;
            clock_count <= clock_count + 1;
            timer_interrupt <= timer_interrupt_nxt;
        end
    end
//cp0_epc for ERET
    assign cp0_epc = EPC;
//interrupt info
    i8 interrupt_info;
    i1 interrupt_en;
    assign interrupt_info = ({ext_int, 2'b00} | Cause.IP | {timer_interrupt, 7'b0}) & Status.IM;
    assign interrupt_en = Status.IE & !Status.EXL;
    assign interrupt = (|interrupt_info) & interrupt_en;
    
//clock interrupt
    i1 isEqual, Compare_set;
    assign isEqual = Compare_set === 1 && Compare === Count;

/* verilator lint_off WIDTH */
    always_comb begin
        BadVAddr_nxt = BadVAddr;
        Count_nxt = Count + clock_count;
        Compare_nxt = Compare;
        Status_nxt = Status;
        Cause_nxt = Cause;
        Cause_nxt.IP = interrupt_info;
        EPC_nxt = EPC;
        timer_interrupt_nxt = timer_interrupt | isEqual;
        if(ERET2pc === 1)begin
            Status_nxt.EXL = 0;
           // Status_nxt.IE = 1;
        end else if(exception === 1)begin
            if(isBadAddr)BadVAddr_nxt = invalid_addr;
            Cause_nxt.ExcCode = m_excCode[4:0];
            if(Status.EXL === 0)begin
                if(inDelaySlot === 0)begin
                    EPC_nxt = excPC;
                    Cause_nxt.BD = 0;
                end else begin
                    EPC_nxt = excPC - 4;
                    Cause_nxt.BD = 1;
                end
                Status_nxt.EXL = 1;
            end
        end else if(cp0_write === 1) begin
            if(cp0_idx === 5'd9)begin
                Count_nxt = cp0_data2w;
            end else if(cp0_idx === 5'd11)begin
                Compare_nxt = cp0_data2w;
                Compare_set = 1;
                timer_interrupt_nxt = 0 | isEqual;
            end else if(cp0_idx === 5'd12)begin
                Status_nxt = (cp0_data2w & CP0_STATUS_MASK) | (Status & ~CP0_STATUS_MASK);
            end else if(cp0_idx === 5'd13)begin
                Cause_nxt.IP[1:0] = cp0_data2w[9:8];
                Cause_nxt.IV = cp0_data2w[23];
            end else if(cp0_idx === 5'd14)begin
                EPC_nxt = cp0_data2w;
            end else begin
            end
        end else begin
        end
    end

/* verilator lint_on WIDTH */
    always_comb begin
        unique case (cp0_idx)
            5'd8: cp0_val = BadVAddr;
            5'd9: cp0_val = Count;
            5'd11: cp0_val = Compare;

            5'd12: cp0_val = Status;
            5'd13: cp0_val = Cause;

            5'd14: cp0_val = EPC;
            default: cp0_val = '0;
        endcase        
    end

    logic _unused_ok = &{1'b0, m_excCode[5] ,Cause_nxt ,1'b0};
    // hhhhhhh
    // can you find me?
endmodule