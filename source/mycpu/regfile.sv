`include "common.svh"
`include "instr.svh"

module regfile(
    input logic clk, resetn,
    input logic write_en1, write_en2,
    input regid_t ra1, ra2, ra3, ra4, wa5, wa6,
    input word_t wd5, wd6,
    output word_t rd1, rd2, rd3, rd4
);
    word_t [31:1] regs, regs_nxt;

    // write: sequential logic
    always_ff @(posedge clk) begin
		if (~resetn) begin
			regs[31:1] <= '0; 
		end else begin
			regs[31:1] <= regs_nxt[31:1];
		end
    end

    for (genvar i = 1; i <= 31; i ++) begin
        always_comb begin
            regs_nxt[i[4:0]] = regs[i[4:0]];
            if (wa5 == i[4:0] && write_en1) begin
                regs_nxt[i[4:0]] = wd5;
            end
            if (wa6 == i[4:0] && write_en2) begin
                regs_nxt[i[4:0]] = wd6;
            end
        end
    end

    // read: combinational logic
    assign rd1 = (ra1 == 5'b0) ? '0 : regs_nxt[ra1];
    assign rd2 = (ra2 == 5'b0) ? '0 : regs_nxt[ra2];
	assign rd3 = (ra3 == 5'b0) ? '0 : regs_nxt[ra3];
    assign rd4 = (ra4 == 5'b0) ? '0 : regs_nxt[ra4];

endmodule