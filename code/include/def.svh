`ifndef __def_SVH__
`define __def_SVH__


`define INVALID 3'b000
`define VALID   3'b001
`define DIRTY   3'b010
`define READING 3'b011
`define WRITING 3'b100
`define DONE    3'b101


parameter int Dcacheline_len = 4 ;     //4 words in one cacheline
parameter int Dcache_set_num = 4 ;     
parameter int Dcache_way_num = 4 ;     

parameter int Dcache_index_bits     =  2 ,  //bits of index
parameter int Dcache_offset_bits    =  4 ,   //bits of offset
parameter int Dcache_tag_bits       =  32-Dcache_index_bits-Dcache_offset_bits;   //bits of tag

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
    msize_t  size;    // write or not
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

typedef struct packed {
    logic    valid;     // in request?
    logic    is_write;  // is it a write transaction?
    msize_t  size;      // number of bytes in one burst
    addr_t   addr;      // start address
    strobe_t strobe;    // which bytes are enabled?
    word_t   data;      // the data to write
    mlen_t   len;       // number of bursts
} cbus_req_t;

typedef struct packed {
    logic  ready;  // is data arrived in this cycle?
    logic  last;   // is it the last word?
    word_t data;   // the data from AXI bus
} cbus_resp_t;

`ifdef VERILATOR
`define STRING string
`else
`define STRING 
`endif


`endif
