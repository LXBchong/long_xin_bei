`include "common.svh"
`include "instr.svh"

module DIV (
    input logic clk, resetn,
    input DIV_input_t in,
    output logic div_halt,
    output i64 c // c = a / b
);
    enum i1 { INIT, DOING } state, state_nxt;
    i35 count, count_nxt;
    localparam i35 DIV_DELAY = {'0, 1'b1, 32'b0};
    always_ff @(posedge clk) begin
        if (~resetn) begin
            {state, count} <= '0;
        end else begin
            {state, count} <= {state_nxt, count_nxt};
        end
    end
    assign div_halt = (state_nxt == DOING);
    always_comb begin
        {state_nxt, count_nxt} = {state, count}; // default
        unique case(state)
            INIT: begin
                if (in.en) begin
                    state_nxt = DOING;
                    count_nxt = DIV_DELAY;
                end
            end
            DOING: begin
                count_nxt = {1'b0, count_nxt[34:1]};
                if (count_nxt == '0) begin
                    state_nxt = INIT;
                end
            end
        endcase
    end
    i64 p, p_nxt;
    always_comb begin
        p_nxt = p;
        unique case(state)
            INIT: begin
                p_nxt = {'0, in.opA};
            end
            DOING: begin
                p_nxt = {p_nxt[63:0], 1'b0};
                if (p_nxt[63:32] >= in.opB) begin
                    p_nxt[63:32] -= in.opB;
                    p_nxt[0] = 1'b1;
                end
            end
        endcase
    end
    always_ff @(posedge clk) begin
        if (~resetn) begin
            p <= '0;
        end else begin
            p <= p_nxt;
        end
    end
    
    always_comb begin
        c = p;
        if(in.signed_a_en && ~in.signed_b_en) begin
            c[63:32] = ~p[63:32] + 32'd1;
            c[31:0] = ~p[31:0] + 32'd1;
        end else if(~in.signed_a_en && in.signed_b_en) begin
            c[31:0] = ~p[31:0] + 32'd1;
         end else if(in.signed_a_en && in.signed_b_en) begin
            c[63:32] = ~p[63:32] + 32'd1;
         end
    end
    
endmodule