`include "access.svh"
`include "common.svh"

module VTop (
    input logic clk, resetn,

    output cbus_req_t  oreq,
    input  cbus_resp_t oresp,

    input i6 ext_int,
    
       output logic[31:0] debug_wb_pc        ,
       output logic[3:0] debug_wb_rf_wen          ,
       output logic[4:0] debug_wb_rf_wnum    ,
       output logic[31:0] debug_wb_rf_wdata 
);
    `include "bus_decl"

    ibus_req_t  ireq, ireq_temp;
    ibus_resp_t iresp;
    dbus_req_t  dreq, dreq_temp;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;

    MyCore core(.ireq(ireq_temp), .dreq(dreq_temp), .*);
    IBusToCBus icvt(.*);
    DBusToCBus dcvt(.*);

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
     	typedef logic [31:0] paddr_t;
        typedef logic [31:0] vaddr_t;
        
        paddr_t paddr,paddr2; // physical address
        vaddr_t vaddr,vaddr2; // virtual address
        
        assign vaddr = ireq_temp.addr;
        assign vaddr2 = dreq_temp.addr;
        assign paddr[27:0] = vaddr[27:0];
        assign paddr2[27:0] = vaddr2[27:0];
        always_comb begin
            unique case (vaddr[31:28])
                4'h8: paddr[31:28] = 4'b0; // kseg0
                4'h9: paddr[31:28] = 4'b1; // kseg0
                4'ha: paddr[31:28] = 4'b0; // kseg1
                4'hb: paddr[31:28] = 4'b1; // kseg1
                default: paddr[31:28] = vaddr[31:28]; // useg, ksseg, kseg3
            endcase
            unique case (vaddr2[31:28])
                4'h8: paddr2[31:28] = 4'b0; // kseg0
                4'h9: paddr2[31:28] = 4'b1; // kseg0
                4'ha: paddr2[31:28] = 4'b0; // kseg1
                4'hb: paddr2[31:28] = 4'b1; // kseg1
                default: paddr2[31:28] = vaddr2[31:28]; // useg, ksseg, kseg3
            endcase
        end
        
        always_comb begin
            ireq = ireq_temp;
            ireq.addr = paddr;
            dreq = dreq_temp;
            dreq.addr = paddr2;
        end

    `UNUSED_OK({ext_int});
endmodule
