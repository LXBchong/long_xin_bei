`include "common.svh"
`include "instr.svh"

module ALU (
    input ALU_input_t   in, 
    output word_t       result,
    output logic        OV,
    output logic        SYS,
    output logic        BR 
);
    
    logic en;
    word_t opA, opB;
    shamt_t shamt;
    arith_t operator;

    //assign en = in.en && ~in.delay_exec.delay_opA && ~in.delay_exec.delay_opB ;
    assign en = in.en;
    assign opA = in.opA;
    assign opB = in.opB;
    assign shamt = in.shamt;
    assign operator = in.operator;

    always_comb begin
       result = 0;

        if(en) begin
            unique case (operator)
                AR_ADD:
                    result = opA + opB;

                AR_ADDU: 
                    result = opA + opB;

                AR_SUB:
                    result = opA - opB;

                AR_SUBU:
                    result = opA - opB;

                AR_SLL:
                    result = opA << shamt;

                AR_SRA:
                    result = $signed(opA) >>> shamt;

                AR_SRL:
                    result = opA >> shamt;

                AR_SLT:
                    result = $signed(opA) < $signed(opB) ? 1 : 0;

                AR_SLTU:
                    result = opA < opB ? 1 : 0; 

                AR_XOR:
                    result = opA ^ opB;
                
                AR_AND:
                    result = opA & opB;

                AR_NOT:
                    result = ~opA;

                AR_OR:
                    result = opA | opB;

                AR_NOR:
                    result = ~(opA | opB);
                    
                AR_LU:
                    result = opB;

                default:
                    result = 0;

            endcase  
        end
    end

    always_comb begin
        OV = 0;
        if(operator == AR_ADD
            && opA[31] == opB[31] && result[31] != opA[31]) begin
                OV = 1;
        end else if(operator == AR_SUB
            && opA[31] != opB[31] && result[31] != opA[31]) begin
                OV = 1;
            end
    end

    assign SYS = operator == AR_SYS;
    assign BR = operator == AR_BR;
    
endmodule