`include "common.svh"
`include "instr.svh"

module fetch1(
    input logic clk, resetn       ,

    output ibus_req_t ireq        ,
    input ibus_resp_t iresp       ,
    input fetch2_BP_bypass_t fetch2_BP_bypass,
    input BRU_BP_bypass_t BRU_BP_bypass,
    output fetch2_input_t out,

    input logic branch_predict_fail, queue_full, flush, d_flush, eret, cp0_flush, f2_flush,
    input addr_t EPC, recover_PC, d_flush_PC, f2_flush_PC
);
    logic fetch1_halt, no_DS, flush_token, is_DS;
    addr_t cur_PC, next_PC;
    branch_predict_t bp_info;
    //assign ireq
    assign ireq.valid = ~queue_full;
    assign ireq.addr = {cur_PC[31:3], 3'b000};

    assign fetch1_halt = ~iresp.data_ok;
    assign no_DS = fetch2_BP_bypass.valid 
        && fetch2_BP_bypass.second_is_branch 
        && cur_PC != fetch2_BP_bypass.PC + 32'd8;

    assign is_DS = fetch2_BP_bypass.valid 
        && fetch2_BP_bypass.second_is_branch 
        && cur_PC == fetch2_BP_bypass.PC + 32'd8;

    branch_predict_v2 branch_predict_ins(.*);

    assign out.cur_PC = {cur_PC[31:3], 3'b000};
    assign out.bp_info = bp_info;
    assign out.iresp = iresp;
    assign out.is_DS = is_DS;
    always_comb begin
        if(fetch1_halt || flush_token)
            out.PC_valid = '0;
        else 
            out.PC_valid = cur_PC[2] == 1 ? 2'b10 : 2'b11;
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            cur_PC <= 32'hbfc00000;
            flush_token <= 0;
        end else if(flush || eret || cp0_flush || no_DS || d_flush || f2_flush) begin
            flush_token <= 1;
            cur_PC <= next_PC;
        end else if(queue_full) begin
            flush_token <= 1;
            //nothing changes, wait for queue to be not full
        end else if(fetch1_halt) begin
            //wait for data_ok
        end else if(flush_token) begin
            flush_token <= 0;
        end else begin
            cur_PC <= next_PC;
        end
    end

endmodule
