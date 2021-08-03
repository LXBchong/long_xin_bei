`ifndef __ICACHE_SVH__
`define __ICAHCE_SVH__


// ICache headfile

`define ICache_offset_bit 3     //8bytes in one cacheline, i.e 2 instrs
`define ICache_index_bit 3      //8 cachesets
`define ICache_position_bit 2   //4 cacheline in one cacheset
`define ICache_instr_num (`ICache_offset_bit-1)

parameter int INSTR_SIZE = `ICache_instr_num;
parameter int INDEX_ROW = 1 << `ICache_index_bit;
parameter int ASSOCIATIVITY = 1 << `ICache_position_bit;
parameter int TAG_BIT = 32 - `ICache_index_bit - `ICache_offset_bit;

typedef logic[TAG_BIT-1:0] tag_t;
typedef logic[`ICache_index_bit-1:0] index_t;
typedef logic[`ICache_offset_bit-1:0] offset_t;
typedef logic[`ICache_position_bit-1:0] position_t;

typedef struct packed {
    tag_t tag;
    logic valid;
} metaUnit_t;
typedef word_t[INSTR_SIZE-1:0] cacheline_t;

typedef metaUnit_t[ASSOCIATIVITY-1:0] meta_set_t;
typedef cacheline_t[ASSOCIATIVITY-1:0] data_set_t;

typedef enum logic { 
    HIT,
    MISS 
} state_t;

typedef enum logic {  
    FULL,
    AVAILABLE
} capacity_t;

typedef union packed {
    position_t hit_pos;
    position_t available_pos;
    position_t replace_pos;
} pos_t;

typedef struct packed {
    index_t index;
    pos_t pos;
    state_t state;
    capacity_t capacity;
    ibus_req_t ireq;
    logic addr_ok;
} register_t;


`endif