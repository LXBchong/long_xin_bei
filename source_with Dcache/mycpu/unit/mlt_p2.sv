`include "common.svh"
`include "instr.svh"

module MLT2 (
    input MLT_input_t in,
    output word_t   p2, p3
);

    assign p2 = in.opA[31:16] * in.opB[15:0];
    assign p3 = in.opA[31:16] * in.opB[31:16];

endmodule