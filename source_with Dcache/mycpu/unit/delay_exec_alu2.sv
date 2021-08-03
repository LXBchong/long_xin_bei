`include "common.svh"
`include "instr.svh"

module ALU (
    input ALU_input_t   in,
    input exec_result_t exec_result, 
    input exec_reg_t exec_reg1, exec_reg2,
    output ALU_input_t out
);

    always_comb begin
        out = in;
        if(in.delay_exec.delay_opA) begin
            if(in.delay_exec.regA == exec_reg1.target_reg && in.delay_exec.fu == exec_reg1.fu) begin
                unique case(in.delay_exec.fu)
                    ALU1:
                        out.opA = exec_result.ALU1_result;
                    
                    ALU2:
                        out.opA = exec_result.ALU2_result;

                    BRU:
                        out.opA = exec_result.BRU_link_PC;

                    MMU:
                        out.opA = exec_result.MMU_result;

                    HILO:
                        out.opA = exec_result.HILO_result;                

                endcase
            end else begin
                out.opA
            end
        end        
    end
    
endmodule