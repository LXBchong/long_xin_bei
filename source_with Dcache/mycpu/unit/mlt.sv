`include "common.svh"
`include "instr.svh"

module MLT (
    input logic clk, resetn,
    input MLT_input_t in,
    output logic mlt_halt,
    output logic[63:0] c // c = a * b
);
    logic [3:0][31:0]p, p_nxt;
    assign p_nxt[0] = in.opA[15:0] * in.opB[15:0];
    assign p_nxt[1] = in.opA[15:0] * in.opB[31:16];
    assign p_nxt[2] = in.opA[31:16] * in.opB[15:0];
    assign p_nxt[3] = in.opA[31:16] * in.opB[31:16];
    
    logic[63:0] c_temp;

    always_ff @(posedge clk) begin
        if (~resetn) begin
            p <= '0;
        end else begin
            p <= p_nxt;
        end
    end
    logic [3:0][63:0] q;
    assign q[0] = {p[0]};
    assign q[1] = {p[1], 16'b0};
    assign q[2] = {p[2], 16'b0};
    assign q[3] = {p[3], 32'b0};
    assign c_temp = q[0] + q[1] + q[2] + q[3];
    assign c = in.signed_en ? ~c_temp + 64'd1 : c_temp;

    enum logic {INIT, DOING} state, state_nxt;
    always_ff @(posedge clk) begin
        if (~resetn) begin
            state <= INIT;
        end else begin
            state <= state_nxt;
        end
    end
    always_comb begin
        state_nxt = state;
        if (state == DOING) begin
            state_nxt = INIT;
        end else if (in.en) begin
            state_nxt = DOING;
        end
    end
    assign mlt_halt = state_nxt == DOING;
endmodule