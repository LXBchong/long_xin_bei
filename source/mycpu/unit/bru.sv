`include "common.svh"
`include "instr.svh"

module BRU (
    input BRU_input_t in,
    output logic branch_predict_fail,
    output addr_t BRU_link_PC, recover_PC,
    output BRU_BP_bypass_t BRU_BP_bypass,
    output logic AdEL,
    output addr_t BadVAddr,
    input logic DS_EXC
);

    logic         en, branch_taken, result, wrong_PC;
    word_t        opA, opB;
    compare_t     operator;

    assign en = in.en;
    assign branch_taken = in.branch_taken;
    assign opA = in.opA;
    assign opB = in.opB;
    assign operator = in.operator;

    //TODO exclude ret && calc wrong addr and wrong jump

    always_comb begin
        result = 0;

        if(en) begin
            unique case (operator)
                CMP_EQL:
                    result = opA == opB;
                
                CMP_GE:
                    result = $signed(opA) >= $signed(opB);

                CMP_LE:
                    result = $signed(opA) <= $signed(opB);

                CMP_NE:
                    result = opA != opB;

                CMP_G:
                    result = $signed(opA) > $signed(opB);

                CMP_L:
                    result = $signed(opA) < $signed(opB);
                    
                 CMP_J:
                    result = 1;
                    
                    default: begin
                        result = 0;
                    end

            endcase
        end
    end

    assign wrong_PC = branch_taken && result && in.predict_PC != in.jump_PC;
    assign branch_predict_fail = (branch_taken != result && ~DS_EXC && ~in.DS_RI) || wrong_PC ? 1 : 0;

    assign BRU_link_PC = in.link_PC;

    assign recover_PC = result ? in.jump_PC : in.link_PC;

    assign AdEL = (result && in.jump_PC[1:0] != 2'b00)
        || (~result && in.link_PC[1:0] != 2'b00);
    
    assign BadVAddr = result ? in.jump_PC : in.link_PC; 

    always_comb begin
        BRU_BP_bypass.branch_in_exec = ~AdEL && ~DS_EXC && en;
        BRU_BP_bypass.branch_result = result;
        BRU_BP_bypass.branch_ins_PC = in.link_PC - 32'd8;
        BRU_BP_bypass.jump_PC = in.jump_PC;
        BRU_BP_bypass.is_ret = in.is_ret;
        BRU_BP_bypass.is_call = in.is_call;
    end

endmodule