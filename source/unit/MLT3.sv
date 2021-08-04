`include "common.svh"
`include "instr.svh"

module MLT3 (
    input MLT_input_t in,
    input word_t[3:0]  p,
    output logic[63:0] c // c = a * b
);
    
    logic[63:0] c_temp;
    logic [3:0][63:0] q;
    assign q[0] = {p[0]};
    assign q[1] = {p[1], 16'b0};
    assign q[2] = {p[2], 16'b0};
    assign q[3] = {p[3], 32'b0};
    assign c_temp = q[0] + q[1] + q[2] + q[3];
    assign c = in.signed_en ? ~c_temp + 64'd1 : c_temp;

endmodule