`include "common.svh"
`include "Myheadfile.svh"
module Freg(
    input i32 F_pc,
    input i1 F_stall, clk, resetn,

    output i32 f_pc, pred_pc,
    output i1 f_vreq,
    output i6 f_excCode
);

    always_ff @(posedge clk) begin
        if(~resetn)begin
            //f_pc <= F_pc;
            pred_pc <= 32'hbfc0_0000;
            f_vreq <= 0;
        end else if(~F_stall)begin
            f_pc <= F_pc;
            pred_pc <= F_pc + 4;
            f_vreq <= 1;
        end
    end
//alignment
    i1 isAddrI_align;
    assign isAddrI_align = (f_vreq === 1) ? f_pc[1:0] === 2'b00 : 1;
    assign f_excCode = isAddrI_align ? 6'b000000 : 6'b100100; //0x04 AdEL
endmodule