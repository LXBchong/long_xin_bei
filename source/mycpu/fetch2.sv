`include "common.svh"
`include "instr.svh"

module fetch2(
    input logic clk, resetn       ,
    input addr_t cur_PC           ,
    output addr_t[1:0] PC         ,
    output instr_t[1:0] instr     ,
    output logic fetch_halt       , 

    input ibus_resp_t iresp       ,

    input logic queue_full, flush,
    input logic eret, cp0_flush
);
    logic branch_taken, flush_token;

    addr_t[1:0] PC_temp, PC_temp_nxt;
    instr_t[1:0] instr_temp, instr_temp_nxt;

    //no cache bit
    always_comb begin
        PC_temp_nxt[0] = cur_PC;
        PC_temp_nxt[1] = cur_PC + 32'd4;
        instr_temp_nxt[0] = iresp.data[31:0];
        instr_temp_nxt[1] = iresp.data[63:32];
    end

    assign fetch_halt = ~iresp.data_ok;
    
    assign PC = fetch_halt || flush || queue_full ? 0 : PC_temp;
    assign instr = fetch_halt || flush || queue_full ? 0 : instr_temp;

    always_ff @(posedge clk) begin
        if(~resetn) begin
            PC_temp <= '0;
            instr_temp <= '0;
            flush_token <= 0;
        end else if(flush || eret || cp0_flush) begin
            flush_token <= 1;
        end else if(queue_full) begin
            //nothing changes, wait for queue to be not full
        end else if(fetch_halt && flush_token) begin
            flush_token <= '0;
        end else if(fetch_halt) begin
            
        end else begin
            PC_temp <= PC_temp_nxt;
            instr_temp <= instr_temp_nxt;
        end
    end

endmodule
