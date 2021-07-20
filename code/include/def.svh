`ifndef __def_SVH__
`define __def_SVH__


`define instr_num 4

typedef logic[31:0] word_t;
typedef logic[4:0] strobe_t;
typedef logic[31:0] addr_t;

typedef enum logic[2:0] {
    MSIZE1,
    MSIZE2,
    MSIZE4
} msize_t;

// length of a burst transaction
// NOTE: WRAP mode in AXI3 only supports power-of-2 length.
typedef enum logic[3:0] {
    MLEN1  = 4'b0000,
    MLEN2  = 4'b0001,
    MLEN4  = 4'b0011,
    MLEN8  = 4'b0111,
    MLEN16 = 4'b1111
} mlen_t;

typedef struct packed {
    logic    valid;   // in request?
    addr_t   addr;    // target address
    logic  is_write;    // write or not
    strobe_t strobe;  // which bytes are enabled? set to zeros for read request
    word_t   data;    // the data to write
} dbus_req_t;

typedef struct packed {
    logic  addr_ok;  // is the address accepted by cache?
    logic  data_ok;  // is the field "data" valid?
    word_t data;     // the data read from cache
} dbus_resp_t;

typedef struct packed {
    logic valid;
    addr_t addr;
} ibus_req_t;

typedef struct packed {
    logic  addr_ok;  // is the address accepted by cache?
    logic  data_ok;  // is the field "data" valid?
    word_t [instr_num-1:0] data;     // the data read from cache
} ibus_resp_t;

`endif