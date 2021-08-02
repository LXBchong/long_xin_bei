#pragma once

#include "defs.h"
#include "memory.h"
#include "reference.h"

const int OFFSET_BITS = 4;
const int INDEX_BITS = 2;
const int OAI_BITS = OFFSET_BITS + INDEX_BITS;
const int TAG_BITS = 32 - OAI_BITS;
const int WORDS_NUM = 1 << (OFFSET_BITS-2); 
const int BYTES_NUM = 1 << OFFSET_BITS;
const int SETS_NUM = 1 << INDEX_BITS;

typedef word_t tag_t;
typedef word_t index_t;
typedef word_t offset_t;
typedef word_t position_t;

struct meta_t{
    tag_t tag;
    bool valid;
    bool dirty;
};

class MyCache;

class CacheRefModel final : public ICacheRefModel {
public:
    CacheRefModel(MyCache *_top, size_t memory_size);

    void reset();
    auto load(addr_t addr, AXISize size) -> word_t;
    void store(addr_t addr, AXISize size, word_t strobe, word_t data);
    void check_internal();
    void check_memory();

private:
    word_t buffer[SETS_NUM][4][WORDS_NUM];
    meta_t meta[SETS_NUM][4];

    MyCache *top;
    VModelScope *scope;

    /**
     * TODO (Lab3) declare reference model's memory and internal states :)
     *
     * NOTE: you can use BlockMemory, or replace it with anything you like.
     */

    // int state;
    BlockMemory mem;
    void fetch(index_t index, position_t position, addr_t addr);
    void save(index_t index, position_t position, addr_t addr);
};
