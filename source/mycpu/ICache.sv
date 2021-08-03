`include "common.svh"
`include "instr.svh"

module ICache (
    input logic clk, resetn,

    input  ibus_req_t  ireq,
    output ibus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp
);

    addr_t vaddr;

    assign vaddr = ireq.addr;

    ibus_req_t real_ireq;

    logic uncachedI;

    always_comb begin
        real_ireq = ireq;
        uncachedI = 0;
        unique case (ireq.addr[31:28])
            4'h8: real_ireq.addr[31:28] = 4'b0;
            4'h9: real_ireq.addr[31:28] = 4'b1;
            4'ha: begin
                real_ireq.addr[31:28] = 4'b0;
                uncachedI = 1;
            end 
            4'hb: real_ireq.addr[31:28] = 4'b1;
        endcase
    end

    ICache_final ICache_inst(
        .clk,
        .resetn,
        .i_uncached(uncachedI),
        .cache_ireq(real_ireq),
        .cache_iresp(iresp),
        .ireq_vaddr(vaddr),
        .cbus_resp(icresp),
        .cbus_req(icreq)
    );
endmodule
