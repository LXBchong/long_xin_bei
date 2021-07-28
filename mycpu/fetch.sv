`include "common.svh"
`include "instr.svh"

module fetch(
    input logic clk, resetn       ,
    output addr_t[1:0] PC         ,
    output instr_t[1:0] instr     ,
    output logic fetch_halt       , 

    output ibus_req_t ireq        ,
    input ibus_resp_t iresp       ,

    input addr_t PC_not_taken     ,
    input logic branch_predict_fail,
    input logic queue_full, flush,
    input logic eret, cp0_flush,
    input addr_t EPC
);
    logic branch_taken, flush_token;
    addr_t cur_PC, next_PC, work_PC, work_PC_nxt;

    addr_t[1:0] PC_temp, PC_temp_nxt;
    instr_t[1:0] instr_temp, instr_temp_nxt;
    logic[1:0] tag, tag_nxt;

    //no cache bit
    assign work_PC_nxt = work_PC + 32'd4;
    assign tag_nxt = tag + 2'd1;
    always_comb begin
        PC_temp_nxt = PC_temp;
        instr_temp_nxt = instr_temp;
        PC_temp_nxt[tag] = work_PC;
        instr_temp_nxt[tag] = iresp.data;
    end

    //assign ireq
    assign ireq.valid = 1;
    assign ireq.addr = work_PC;

    assign fetch_halt = tag == 2'd2 ? 0 : 1;

    branch_predict branch_predict_ins(.*);
    
    assign PC = fetch_halt || flush || queue_full ? 0 : PC_temp;
    assign instr = fetch_halt || flush || queue_full  ? 0 : instr_temp;

    always_ff @(posedge clk) begin
        if(~resetn) begin
            tag <= '0;
            cur_PC <= 32'hbfc00000;
            work_PC <= 32'hbfc00000;
            PC_temp <= '0;
            instr_temp <= '0;
            flush_token <= 0;
        end else if(flush || eret || cp0_flush) begin
            tag <= '0;
            cur_PC <= next_PC;
            work_PC <= next_PC;
            flush_token <= 1;
        end else if(queue_full) begin
            //nothing changes, wait for queue to be not full
        end else if(fetch_halt && iresp.data_ok && flush_token) begin
            tag <= '0;
            flush_token <= '0;
        end else if(fetch_halt && iresp.data_ok) begin
            PC_temp <= PC_temp_nxt;
            instr_temp <= instr_temp_nxt;
            work_PC <= work_PC_nxt;
            tag <= tag_nxt;
        end else if(fetch_halt) begin
            PC_temp <= PC_temp_nxt;
            instr_temp <= instr_temp_nxt;
        end else begin
            tag <= '0;
            cur_PC <= next_PC;
            work_PC <= next_PC;
        end
    end

endmodule
