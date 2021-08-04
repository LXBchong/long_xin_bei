`include "common.svh"
`include "instr.svh"

module MLT1 (
    input MLT_input_t in,
    output word_t   p0, p1
);

    assign p0 = in.opA[15:0] * in.opB[15:0];
    assign p1 = in.opA[15:0] * in.opB[31:16];

endmodule