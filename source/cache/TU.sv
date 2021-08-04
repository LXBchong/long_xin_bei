`include "common.svh"

module TU(
    input dbus_req_t dreq,
    input ibus_req_t ireq,

    output dbus_req_t t_dreq,  //translated dreq
    output ibus_req_t t_ireq,  //translated ireq

    output logic d_uncached, i_uncached
);

assign i_uncached = ireq.addr[31:28] == 4'ha || ireq.addr[31:28] == 4'hb ? 1'b1:1'b0;
assign d_uncached = dreq.addr[31:28] == 4'ha || dreq.addr[31:28] == 4'hb ? 1'b1:1'b0;

always_comb begin
    t_dreq.valid=dreq.valid;        // in request?
    t_dreq.size=dreq.size;  // write or not
    t_dreq.strobe=dreq.strobe;      // which bytes are enabled?
    t_dreq.data=dreq.data;          // the data to write

    unique case (dreq.addr[31:28])
        4'h8: t_dreq.addr = {4'b0,dreq.addr[27:0]}; // kseg0
        4'h9: t_dreq.addr = {4'b1,dreq.addr[27:0]}; // kseg0
        4'ha: t_dreq.addr = {4'b0,dreq.addr[27:0]}; // kseg1
        4'hb: t_dreq.addr = {4'b1,dreq.addr[27:0]}; // kseg1
        default:t_dreq.addr= dreq.addr; // useg, ksseg, kseg3
    endcase  
end

always_comb begin
    t_ireq.valid=ireq.valid;        // in request?

    unique case (ireq.addr[31:28])
        4'h8: t_ireq.addr = {4'b0,ireq.addr[27:0]}; // kseg0
        4'h9: t_ireq.addr = {4'b1,ireq.addr[27:0]}; // kseg0
        4'ha: t_ireq.addr = {4'b0,ireq.addr[27:0]}; // kseg1
        4'hb: t_ireq.addr = {4'b1,ireq.addr[27:0]}; // kseg1
        default:t_ireq.addr= ireq.addr; // useg, ksseg, kseg3
    endcase  
end



endmodule
