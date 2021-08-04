`include "common.svh"
`include "instr.svh"

module branch_predict(
    input addr_t cur_PC             ,
    input logic branch_predict_fail ,
    output addr_t next_PC           ,
    input logic eret, cp0_flush     ,
    input addr_t EPC
);
    always_comb begin
        next_PC = cur_PC + 32'd8;
        if(cp0_flush)
            next_PC = 32'hbfc00380;
        else if(eret)
            next_PC = EPC;
        else if(branch_predict_fail)
            next_PC = '0;
    end


endmodule