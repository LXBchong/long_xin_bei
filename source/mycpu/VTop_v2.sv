`include "access.svh"
`include "common.svh"

module VTop_v2 (
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

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;
    //tbus_req_t dtreq;
    //tbus_resp_t dtresp;



    dbus_req_t cache_dreq;
    ibus_req_t cache_ireq;  

    dbus_resp_t cache_dresp;
    ibus_resp_t cache_iresp;

    logic d_uncached,i_uncached;

    MyCore_exc core(.*);
    /*DBusToCBus*/DCache dcvt(.*);
    ICache icvt(.*);
    //IBusToCBus icvt(.*);
    //DBusToCBus dcvt(.*);

    MMU MMU_inst(.*);

    //LoadStoreBuffer LoadStoreBuffer_inst(.*);

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