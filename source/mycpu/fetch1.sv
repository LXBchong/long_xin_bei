`include "common.svh"
`include "instr.svh"

module fetch1(
    input logic clk, resetn       ,

    output ibus_req_t ireq        ,
    input ibus_resp_t iresp       ,
    output addr_t cur_PC_nxt      ,

    input addr_t PC_not_taken     ,
    input logic branch_predict_fail,
    input logic queue_full, flush,
    input logic eret, cp0_flush,
    input addr_t EPC,
    input logic fetch_halt
);
    logic branch_taken, fetch1_halt;
    addr_t cur_PC, next_PC;

    //assign ireq
    assign ireq.valid = 1;
    assign ireq.addr = cur_PC;
    assign ireq.is_stall = fetch_halt;

    assign fetch1_halt =  ~iresp.addr_ok;

    branch_predict branch_predict_ins(.*);

    assign cur_PC_nxt = cur_PC;

    always_ff @(posedge clk) begin
        if(~resetn) begin
            cur_PC <= 32'hbfc00000;
        end else if(flush || eret || cp0_flush) begin
            cur_PC <= next_PC;
        end else if(queue_full) begin
            //nothing changes, wait for queue to be not full
        end else if(fetch1_halt) begin
            //wait for addr_ok
        end else begin
            cur_PC <= next_PC;
        end
    end

endmodule
