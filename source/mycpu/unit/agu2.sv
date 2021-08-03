`include "common.svh"
`include "instr.svh"

module AGU2(
    input logic clk, resetn,
    input AGU_input_t in,
    input dbus_req_t dreq_temp,
    output dbus_req_t dreq,
    input dbus_resp_t dresp,

    input logic mem_halt,
    output logic mem_addr_halt
);
    logic addr_ok_got, addr_ok_got_nxt;

    always_comb begin
        dreq = dreq_temp;
        dreq.valid = dreq_temp.valid && ~addr_ok_got;
    end
    
    assign mem_addr_halt = in.en && dreq.valid && ~dresp.addr_ok && ~addr_ok_got;
    
    always_comb begin
        addr_ok_got_nxt = addr_ok_got;
        if(dresp.addr_ok)
            addr_ok_got_nxt = 1;
        if(~mem_halt)
            addr_ok_got_nxt = 0;
    end
    
    always_ff @(posedge clk) begin
        if(~resetn)
            addr_ok_got <= '0;
        else
            addr_ok_got <= addr_ok_got_nxt;
    end

endmodule