`include "access.svh"
`include "common.svh"

module VTop (
    input logic clk, resetn,

    output cbus_req_t  oreq,
    input  cbus_resp_t oresp,

    input i6 ext_int
);
    `include "bus_decl"

    ibus_req_t  ireq;
    ibus_resp_t iresp;

    cbus_req_t  icreq,  dcreq;


    dbus_req_t  dreq;
    dbus_resp_t dresp;

    cbus_resp_t icresp, dcresp;
    i1 uncachedD, uncachedI;

    MyCore core(.*);
    
    ICache icvt(.creq(icreq), .cresp(icresp), .*);
    DCache dcvt(.creq(dcreq), .cresp(dcresp), .*);
    /*
    IBusToCBus icvt(.*);
    DBusToCBus dcvt(.*);
    */
    /**
     * TODO (Lab2) replace mux with your own arbiter :)
     */
/*
    CBusMultiplexer mux(
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .*
    );
*/
    CBusArbiter mux(
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .*
    );
    
    /**
     * TODO (optional) add address translation for oreq.addr :)
     */

    `UNUSED_OK({ext_int});
endmodule
