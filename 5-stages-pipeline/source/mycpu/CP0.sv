`include "common.svh"
`include "Myheadfile.svh"
module CP0(
    input i1 clk, resetn,
    input i32 cp0_data2w, invalid_addr, excPC,  
    input i5 cp0_idx,
    input i1 cp0_write, exception, isBadAddr, inDelaySlot, ERET2pc,
    input i6 ext_int,
    (*mark_debug = "true"*)input i6 m_excCode,

    output i32 cp0_val, cp0_epc, 
    (*mark_debug = "true"*)output i1 interrupt
);
//variable defination
    typedef struct packed {
        i8 IM;   //interrupt enable
        i1 EXL;
        i1 IE;  //in exception dealt?
    } Status_t;

    typedef struct packed {
        i1 BD;    //in delay slot ?   
        i8 IP;
        i5 ExcCode;     
    } Cause_t;

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
            Status <= {8'h00, 1'b0, 1'b1};
            clock_count <= '0;
            timer_interrupt <= '0;
        end else begin
            BadVAddr <= BadVAddr_nxt;
            Count <= Count_nxt;
            Compare <= Compare_nxt;
            Status <= Status_nxt;
            Cause <= {Cause_nxt.BD, interrupt_info, Cause_nxt.ExcCode};
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

//special dealt
    i32 Cause_val, Status_val;
    assign Status_val = {16'h0040, Status.IM, 6'b000000, Status.EXL, Status.IE};
    assign Cause_val = {Cause.BD, 15'h0000, Cause.IP, 1'b0, Cause.ExcCode, 2'b00};
    
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
                Status_nxt = {cp0_data2w[15:8], cp0_data2w[1], cp0_data2w[0]};
            end else if(cp0_idx === 5'd13)begin
                Cause_nxt.IP[1:0] = cp0_data2w[9:8];
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

            5'd12: cp0_val = Status_val;
            5'd13: cp0_val = Cause_val;

            5'd14: cp0_val = EPC;
            default: cp0_val = '0;
        endcase        
    end

    logic _unused_ok = &{1'b0, m_excCode[5] ,Cause_nxt ,1'b0};
    // hhhhhhh
    // can you find me?
endmodule