`include "common.svh"
//typedef logic[31:0] word_t;
typedef logic[4:0] creg_addr_t;

module Regfile(
    input logic clk,
    input creg_addr_t ra1, ra2, wa3,
    input i4 write_enable,
    input word_t wd3,
    output word_t rd1, rd2
);
    word_t [31:1] regs, regs_nxt;

    // write: sequential logic
    always_ff @(posedge clk) begin
        regs[31:1] <= regs_nxt[31:1];
    end
    for (genvar i = 1; i <= 31; i ++) begin
        always_comb begin
            regs_nxt[i[4:0]] = regs[i[4:0]];
            if (wa3 == i[4:0] && (write_enable === 4'b1111)) begin
                regs_nxt[i[4:0]] = wd3;
            end
        end
    end


    // read: combinational logic
    assign rd1 = (ra1 == 5'b0) ? '0 : regs[ra1]; // or regs_nxt[ra1] ?
    assign rd2 = (ra2 == 5'b0) ? '0 : regs[ra2];

endmodule
