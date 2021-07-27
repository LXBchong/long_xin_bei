`include "def.svh"

module MMU (
    input logic clk,resetn,

    input dbus_req_t dreq,
    input ibus_req_t ireq,

    output dbus_resp_t dresp, 
    output ibus_resp_t iresp,

    output dbus_req_t cache_dreq,
    output ibus_req_t cache_ireq,  //translated ireq

    input dbus_resp_t cache_dresp
);

logic i_uncached,d_uncached;

logic skid_free;
dbus_req_t skid_buffer;


dbus_req_t t_dreq;
ibus_req_t t_ireq;

assign cache_dreq = skid_free ? t_dreq : skid_buffer ;

always_comb begin
    dresp = cache_dresp;
    dresp.addr_ok = dreq.valid?skid_free:1'b0;;
end

TU TU_inst(.*);   // Translation Unit
DCache DCache_inst(.*);

always_ff @(posedge clk) begin
    if(resetn) begin
        if(cache_dresp.addr_ok) skid_free<=1'b1;
        else if(dreq.valid && skid_free) begin
            skid_free  <=1'b0;
            skid_buffer<=t_dreq;
        end
    end
    else begin
        skid_free<=1'b1;
        skid_buffer<='0;
    end
end

    
endmodule
