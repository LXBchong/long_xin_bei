`include "common.svh"
`include "instr.svh"

module BRU (
    input BRU_input_t in,
    output logic branch_predict_fail,
    output addr_t BRU_link_PC, PC_not_taken,
    output logic AdEL,
    output addr_t BadVAddr,
    input logic DS_EXC
);

    logic         en, branch_taken, result;
    word_t        opA, opB;
    compare_t     operator;

    assign en = in.en;
    assign branch_taken = in.branch_taken;
    assign opA = in.opA;
    assign opB = in.opB;
    assign operator = in.operator;

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

    assign branch_predict_fail = (branch_taken != result && ~DS_EXC && ~in.DS_RI) ? 1 : 0;

    assign BRU_link_PC = in.link_PC;

    assign PC_not_taken = branch_taken ? in.link_PC : in.jump_PC;

    assign AdEL = (result && in.jump_PC[1:0] != 2'b00)
        || (~result && in.link_PC[1:0] != 2'b00);

    assign BadVAddr = result ? in.jump_PC : in.link_PC; 

endmodule