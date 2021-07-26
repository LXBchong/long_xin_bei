`ifndef __BASIC_SVH__
`define __BASIC_SVH__

typedef logic[31:0] word_t;
typedef logic[31:0] addr_t;

typedef enum i3 {
    MSIZE1,
    MSIZE2,
    MSIZE4
} msize_t;

typedef logic[3:0] strobe_t;

typedef logic[4:0] regid_t;

typedef struct packed {
    logic    valid;  
    addr_t   addr;    
    msize_t  size;    
    strobe_t strobe;  
    word_t   data;    
} dbus_req_t;

typedef struct packed {
    logic  addr_ok;  
    logic  data_ok;  
    word_t data;     
} dbus_resp_t;

typedef struct packed {
    logic  valid; 
    addr_t addr;   
} ibus_req_t;

typedef dbus_resp_t ibus_resp_t;

`endif