`include "common.svh"
`include "instr.svh"

module hilo_reg(
    input logic clk, resetn,
    input logic write_hi_en, write_lo_en,
    input word_t hi_data, lo_data,
    output word_t hi, lo
);
    word_t hi_reg, lo_reg, hi_nxt, lo_nxt;

    // write: sequential logic
    always_ff @(posedge clk) begin
		if (~resetn) begin
			hi_reg <= '0;
            lo_reg <= '0;
		end else begin
			hi_reg <= hi_nxt;
            lo_reg <= lo_nxt;
		end
    end

    always_comb begin
        hi_nxt = write_hi_en ? hi_data : hi_reg;
        lo_nxt = write_lo_en ? lo_data : lo_reg;
    end

    // read: combinational logic
    assign hi = hi_nxt;
    assign lo = lo_nxt;

endmodule