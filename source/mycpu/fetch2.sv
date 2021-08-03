`include "common.svh"
`include "instr.svh"

module fetch2(
    input fetch2_input_t in       ,
    output decode_input_t decode_input,
    output fetch2_BP_bypass_t fetch2_BP_bypass, 

    input logic queue_full, flush,
    input logic eret, cp0_flush,
    output logic f2_flush,
    output addr_t f2_flush_PC
);

    addr_t cur_PC;
    branch_predict_t bp_info_out;
    addr_t[1:0] PC, PC_temp;
    instr_t[1:0] instr, instr_temp;
    ibus_resp_t iresp;

    assign cur_PC = in.cur_PC;
    assign iresp = in.iresp;

    always_comb begin
        bp_info_out.branch_taken = in.bp_info.branch_taken;
        bp_info_out.predict_PC = iresp.predecode[1] != normal ? '0  : in.bp_info.predict_PC;
        if(f2_flush) begin
            bp_info_out.branch_taken = 0;
            bp_info_out.predict_PC = f2_flush_PC;
        end
    end
    
    assign decode_input.PC_valid = in.PC_valid;
    assign decode_input.bp_info = bp_info_out;
    assign decode_input.PC = PC;
    assign decode_input.instr = instr;
    assign decode_input.is_ret[0] = iresp.predecode[0] == is_ret ? 1: 0;
    assign decode_input.is_ret[1] = iresp.predecode[1] == is_ret ? 1: 0;  
    assign decode_input.is_call[0] = iresp.predecode[0] == is_call ? 1: 0;  
    assign decode_input.is_call[1] = iresp.predecode[1] == is_call ? 1: 0;  

    //no cache bit
    always_comb begin
        PC_temp[0] = cur_PC;
        PC_temp[1] = cur_PC + 32'd4;
        instr_temp[0] = iresp.data[0];
        instr_temp[1] = iresp.data[1];
    end

    //some problem here 
    /*assign f2_flush = iresp.data_ok && 
                        ((~branch_taken && iresp.is_call)
                        || (~branch_taken && iresp.is_ret)); */
    //assign f2_flush = iresp.data_ok && ~branch_taken && iresp.is_ret;
    assign f2_flush = iresp.data_ok && in.bp_info.branch_taken && ~in.is_DS 
        && ((in.PC_valid == 2'b11 && iresp.predecode[0] == normal && iresp.predecode[1] == normal)
            ||(in.PC_valid == 2'b10 &&  iresp.predecode[1] == normal)); //REVIEW
    assign f2_flush_PC = cur_PC + 32'd8;

    assign PC = flush || queue_full ? 0 : PC_temp;
    assign instr = flush || queue_full ? 0 : instr_temp;

    //TODO maybe we need is_branch info, so I wrote this comment just in case we autually need it 
    assign fetch2_BP_bypass.valid = iresp.data_ok && in.PC_valid != '0;
    assign fetch2_BP_bypass.PC = cur_PC;
    assign fetch2_BP_bypass.second_is_branch = iresp.predecode[1] != normal;
    assign fetch2_BP_bypass.is_ret[0] =  iresp.predecode[0] == is_ret;
    assign fetch2_BP_bypass.is_ret[1] =  iresp.predecode[1] == is_ret;


endmodule
