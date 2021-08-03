`include "common.svh"

module MMU (
    input logic clk,resetn,

    input dbus_req_t dreq,


    output dbus_resp_t dresp, 


    output dbus_req_t cache_dreq,


    input dbus_resp_t cache_dresp,
    
    output logic d_uncached
);

logic d_skid_free;
dbus_req_t d_skid_buffer;


dbus_req_t t_dreq;


assign cache_dreq = d_skid_free ? t_dreq : d_skid_buffer ;

always_comb begin
    dresp = cache_dresp;
    dresp.addr_ok = dreq.valid?d_skid_free:1'b0;;
end

TU TU_inst(.*);   // Translation Unit

always_ff @(posedge clk) begin
    if(resetn) begin
        if(cache_dresp.addr_ok) begin
            d_skid_buffer<='0;
            d_skid_free<=1'b1;
        end
        else if(dreq.valid && d_skid_free) begin
            d_skid_free  <=1'b0;
            d_skid_buffer<=t_dreq;
        end
    end
    else begin
        d_skid_free<=1'b1;
        d_skid_buffer<='0;
    end
end

    
endmodule
