`ifndef __ICACHE_SVH__
`define __ICAHCE_SVH__


// ICache headfile
`define ICache_offset_bit 3     //8bytes in one cacheline, i.e 2 instrs
`define ICache_index_bit 3      //8 cachesets
`define ICache_position_bit 2   //4 cacheline in one cacheset
`define ICache_instr_num (`ICache_offset_bit-1)

typedef enum logic[1:0] {
    normal,
    is_branch,
    is_ret,
    is_call
} predecode_rslt_t;

typedef enum logic { 
    MODIFY, //hit or miss but available
    REPLACE //miss and full
} LRU_func_t;

typedef struct packed {
    logic  addr_ok;  // is the address accepted by cache?
    logic  data_ok;  // is the field "data" valid?
    predecode_rslt_t[`ICache_instr_num -1:0]  predecode_rslt;// the result of predecode
    word_t [`ICache_instr_num -1:0] data;     // the data read from cache
} ibus_resp_t;

/*
typedef union packed {
    byte_t [CBUS_DATA_BYTES - 1:0] bytes;
    cbus_word_t                    word;
} cbus_view_t;
*/

/*typedef struct packed {
    logic       okay;
    logic       last;
    cbus_view_t rdata;
} cbus_resp_t; */

`endif