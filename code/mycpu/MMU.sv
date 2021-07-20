`include "def.svh"

module MMU (
    input logic clk,resetn,

    input dbus_req_t dreq,
    input ibus_req_t ireq,

    output dbus_resp_t dresp, 
    output ibus_resp_t iresp,

    output dbus_req_t t_dreq, //translated dreq
    output ibus_req_t t_ireq  //translated ireq
);

logic i_uncached,d_uncached;

TU TU_inst(.*);
    
endmodule