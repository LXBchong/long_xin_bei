`include "common.svh"
`include "instr.svh"

module decode(
    input logic clk, resetn       ,
    input decode_input_t in       ,
    output decode_t[1:0] decode_info,
    output logic[1:0] decode_en,
    output logic d_flush,
    output addr_t d_flush_PC
);

    decoder_input_t decoder1_input, decoder2_input;
    decode_t decode_info1, decode_info2;
    branch_buffer_t branch_buffer, branch_buffer_nxt;
    logic d_flush1, d_flush2, is_first_DS, is_ret1, is_ret2, is_call1, is_call2;
    addr_t flush_PC1, flush_PC2;
    branch_predict_t[1:0] bp_info;

    assign decoder1_input.en = in.PC_valid[0];
    assign decoder1_input.first = 1;
    assign decoder1_input.PC = in.PC[0];
    assign decoder1_input.instr = in.instr[0];

    assign decoder2_input.en = in.PC_valid[1];
    assign decoder2_input.first = 0;
    assign decoder2_input.PC = in.PC[1];
    assign decoder2_input.instr = in.instr[1];

    decoder decoder_ins1(decoder1_input, branch_buffer, in.bp_info, decode_info1, bp_info[0], d_flush1, flush_PC1);
    decoder decoder_ins2(decoder2_input, branch_buffer, in.bp_info, decode_info2, bp_info[1], d_flush2, flush_PC2);

    assign is_first_DS = in.PC_valid[0] && branch_buffer.valid && in.PC[0] == branch_buffer.PC + 32'd8;

    always_comb begin
        branch_buffer_nxt = branch_buffer;
        if(is_first_DS)
            branch_buffer_nxt = '0;
        if(in.PC_valid[1] && decode_info2.unit == U_BRANCH) begin
            branch_buffer_nxt.valid = 1;
            branch_buffer_nxt.PC = in.PC[0];
            branch_buffer_nxt.jump_PC = decode_info2.jump_PC;
            branch_buffer_nxt.opcode = in.instr[1].opcode;
            branch_buffer_nxt.must_jump = decode_info2.cmp == CMP_J;
        end
    end

    always_comb begin
        decode_en = in.PC_valid;
        if(d_flush1 && is_first_DS)
            decode_en[1] = 0;
    end

    assign d_flush = d_flush1;
    assign d_flush_PC = flush_PC1;

    assign is_ret1 = in.is_ret[0];
    assign is_ret2 = in.is_ret[1];
    assign is_call1 = in.is_call[0];
    assign is_call2 = in.is_call[1];

    always_comb begin
        decode_info[0] = decode_info1;
        decode_info[1] = decode_info2;
        decode_info[0].bp_info = bp_info[0];
        decode_info[1].bp_info = bp_info[1];
        decode_info[0].is_ret = is_ret1;
        decode_info[1].is_ret = is_ret2;
        decode_info[0].is_call = is_call1;
        decode_info[1].is_call = is_call2;
    end
    
    always_ff @(posedge clk) begin
        if(~resetn) begin
            branch_buffer <= '0;
        end else begin
            branch_buffer <= '0;
        end
    end

endmodule
