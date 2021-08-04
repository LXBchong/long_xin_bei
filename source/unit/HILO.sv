`include "common.svh"
`include "instr.svh"

module HILO(
    input HILO_input_t in,
    input word_t hi, lo,
    input logic[63:0] DIV_result_bypass,
    input function_unit_t fu,
    output logic write_hi_en, write_lo_en,
    output word_t hilo_result
);

    always_comb begin
        hilo_result = '0;
        if(in.read_hi)begin
            hilo_result = hi;
            if(fu == DIV)
                hilo_result = DIV_result_bypass[63:32];
        end else if(in.read_lo)begin
            hilo_result = lo;
            if(fu == DIV)
                hilo_result = DIV_result_bypass[31:0];
        end else if(in.write_hi || in.write_lo)begin
            hilo_result = in.data;
        end
    end

    assign write_hi_en = in.write_hi;
    assign write_lo_en = in.write_lo;

endmodule