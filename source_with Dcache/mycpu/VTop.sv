`include "access.svh"
`include "common.svh"

module VTop (
    input logic clk, resetn,

    output cbus_req_t  oreq,
    input  cbus_resp_t oresp,

    input i6 ext_int,
    
       output logic[31:0] debug_wb_pc        ,
       output logic[3:0] debug_wb_rf_wen     ,
       output logic[4:0] debug_wb_rf_wnum    ,
       output logic[31:0] debug_wb_rf_wdata 
);
    `include "bus_decl"

    logic d_uncached;
    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq, cache_dreq;
    dbus_resp_t dresp, cache_dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;

    MyCore core(.*);
    /*IBusToCBus*/  DCache dcvt(.*);
    /*DBusToCBus*/  ICache icvt(.*);
    //IBusToCBus icvt(.*);
    //DBusToCBus dcvt(.*);
    MMU MMU_ins(.*);

    /**
     * TODO (Lab2) replace mux with your own arbiter :)
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
