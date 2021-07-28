`include "common.svh"
`include "instr.svh"

module debug_queue(
    input logic clk, resetn,
    input addr_t debug_pc1, debug_pc2,
    input logic debug_wen1, debug_wen2,
    input regid_t debug_wnum1, debug_wnum2,
    input word_t debug_data1, debug_data2,
    input logic[1:0] debug_en,

    output logic[31:0] debug_wb_pc        ,
    output logic[3:0] debug_wb_rf_wen          ,
    output logic[4:0] debug_wb_rf_wnum    ,
    output logic[31:0] debug_wb_rf_wdata  
);

    addr_t[127:0] dq_pc, dq_pc_nxt;
    logic[127:0] dq_en, dq_en_nxt;
    regid_t[127:0] dq_wnum, dq_wnum_nxt;
    word_t[127:0] dq_data, dq_data_nxt;

    addr_t debug_pc_nxt;
    logic[3:0] debug_en_nxt;
    logic[4:0] debug_reg_nxt;
    word_t debug_data_nxt;

    logic[6:0] head, tail, head_nxt, tail_nxt, tail_plus_one;

    assign tail_plus_one = tail + 7'd1;

    always_comb begin
        dq_pc_nxt = dq_pc;
        dq_en_nxt = dq_en;
        dq_wnum_nxt = dq_wnum;
        dq_data_nxt = dq_data;

        if(debug_en[0] && debug_pc1 != '0) begin
            dq_pc_nxt[tail] = debug_pc1;
            dq_en_nxt[tail] = debug_wen1;
            dq_wnum_nxt[tail] = debug_wnum1;
            dq_data_nxt[tail] = debug_data1;
        end

        if(debug_en[1] && debug_pc2 != '0) begin
            dq_pc_nxt[tail_plus_one] = debug_pc2;
            dq_en_nxt[tail_plus_one] = debug_wen2;
            dq_wnum_nxt[tail_plus_one] = debug_wnum2;
            dq_data_nxt[tail_plus_one] = debug_data2;
        end

        if(head != tail) begin
            dq_pc_nxt[head] = '0;
            dq_en_nxt[head] = '0;
            dq_wnum_nxt[head] = R0;
            dq_data_nxt[head] = '0;
        end
    end

    assign tail_nxt = tail + {6'd0, debug_en[0]} + {6'd0, debug_en[1]};

    always_comb begin
        //debug_pc_nxt = debug_wb_pc;
        //debug_en_nxt = debug_wb_rf_wen;
        //debug_reg_nxt = debug_wb_rf_wnum;
        //debug_data_nxt = debug_wb_rf_wdata;
        //head_nxt = head;
        if(head != tail) begin
            debug_pc_nxt = dq_pc[head];
            debug_en_nxt = dq_en[head] ? 4'b1111 : 4'b0000;
            debug_reg_nxt = dq_wnum[head];
            debug_data_nxt = dq_data[head];
            head_nxt = head + 7'd1;
            
        end else begin
            debug_pc_nxt = '0;
            debug_en_nxt = 4'b0000;
            debug_reg_nxt = R0;
            debug_data_nxt = '0;
            head_nxt = head;
            
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            head <= '0;
            tail <= '0;
            dq_pc <= '0;
            dq_en <= '0;
            dq_wnum <= '0;
            dq_data <= '0;
            debug_wb_pc <= '0;
            debug_wb_rf_wdata <= '0;
            debug_wb_rf_wen <= 0;
            debug_wb_rf_wnum <= '0;
        end else begin
            head <= head_nxt;
            tail <= tail_nxt;
            dq_pc <= dq_pc_nxt;
            dq_en <= dq_en_nxt;
            dq_wnum <= dq_wnum_nxt;
            dq_data <= dq_data_nxt;
            debug_wb_pc <= debug_pc_nxt;
            debug_wb_rf_wdata <= debug_data_nxt;
            debug_wb_rf_wen <= debug_en_nxt;
            debug_wb_rf_wnum <= debug_reg_nxt;
        end
    end
    
endmodule