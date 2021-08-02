#include "mycache.h"
#include "cache_ref.h"
#include<stdio.h>
#include<cstring>

CacheRefModel::CacheRefModel(MyCache *_top, size_t memory_size)
    : top(_top), scope(top->VCacheTop), mem(memory_size) {
    /**
     * TODO (Lab3) setup reference model :)
     */
    mem.set_name("ref");
}

void CacheRefModel::reset() {
    /**
     * TODO (Lab3) reset reference model :)
     */
// buffer and meta reset
    log_debug("ref: reset()\n");
	memset(buffer, 0, sizeof(buffer));
	memset(meta, 0, sizeof(meta));
    mem.reset();
}

void CacheRefModel::fetch(index_t index, position_t position, addr_t addr) {
    addr_t start = (addr >> OFFSET_BITS) << OFFSET_BITS;

    for (int i = 0; i < WORDS_NUM; i++) {
        buffer[index][position][i] = mem.load(start + 4 * i);
    }
}

void CacheRefModel::save(index_t index, position_t position, addr_t addr) {
    addr_t start = (addr >> OFFSET_BITS) << OFFSET_BITS;

    for (int i = 0; i < WORDS_NUM; i++) {
        mem.store(start + 4*i, buffer[index][position][i], STROBE_TO_MASK[0b1111]);
    }
}

auto CacheRefModel::load(addr_t addr, AXISize size) -> word_t {
    /**
     * TODO (Lab3) implement load operation for reference model :)
     */
    bool  EXI = 1, MISS;
    tag_t tag = addr >> OAI_BITS;
    index_t index = (addr << TAG_BITS) >> (TAG_BITS + OFFSET_BITS);
    offset_t offset = (addr << (TAG_BITS + INDEX_BITS)) >> (TAG_BITS + INDEX_BITS + 2);
    position_t position;
    auto foo = meta[index];
    if(foo[0].tag == tag)position = 0;
    else if(foo[1].tag == tag)position = 1;
    else if(foo[2].tag == tag)position = 2;
    else if(foo[3].tag == tag)position = 3;
    else{
        EXI = 0;
        if(!foo[0].valid) position = 0;
        else if(!foo[1].valid) position = 1;
        else if(!foo[2].valid) position = 2;
        else if(!foo[3].valid) position = 3;
        else position = tag & 0x3; 
    }
    MISS = !(EXI & foo[position].valid);
//	printf("in load, MISS: %d  EXI: %d  valid:%d \n", MISS, EXI, foo[position].valid);
    meta_t* cur = &meta[index][position];
    if(MISS){
        if(cur->dirty){
            addr_t cur_addr = (cur->tag << (OAI_BITS)) + (index << OFFSET_BITS);
            save(index, position, cur_addr);
            cur->dirty = 0;
        }
        fetch(index, position, addr);
        cur->valid = 1;
        cur->tag = tag;
    }

    log_debug("ref: load(0x%x, %d)\n", addr, 1 << size);
    return buffer[index][position][offset];
}

void CacheRefModel::store(addr_t addr, AXISize size, word_t strobe, word_t data) {
    /**
     * TODO (Lab3) implement store operation for reference model :)
     */
    bool EXI = 1 ,MISS;
    tag_t tag = addr >> OAI_BITS;
    index_t index = (addr << TAG_BITS) >> (TAG_BITS + OFFSET_BITS);
    offset_t offset = (addr << (TAG_BITS + INDEX_BITS)) >> (TAG_BITS + INDEX_BITS + 2);
    position_t position;
    auto foo = meta[index];
    if(foo[0].tag == tag)position = 0;
    else if(foo[1].tag == tag)position = 1;
    else if(foo[2].tag == tag)position = 2;
    else if(foo[3].tag == tag)position = 3;
    else{
        EXI = 0;
        if(!foo[0].valid) position = 0;
        else if(!foo[1].valid) position = 1;
        else if(!foo[2].valid) position = 2;
        else if(!foo[3].valid) position = 3;
        else position = tag & 0x3; 
    }
    MISS = !(EXI & foo[position].valid);
//	printf("in store, MISS: %d  EXI: %d  valid:%d \n", MISS, EXI, foo[position].valid);
    meta_t* cur = &meta[index][position];
    if(MISS){
        if(cur->dirty){
            addr_t cur_addr = (cur->tag << (OAI_BITS)) + (index << OFFSET_BITS);
            save(index, position, cur_addr);
            cur->dirty = 0;
        }
        fetch(index, position, addr);
        cur->valid = 1;
        cur->tag = tag;
    }
//	printf("index: %d  position: %d offset: %d\n",index, position, offset);
    word_t cur_data = buffer[index][position][offset];
    word_t res = 0;
    word_t mask = STROBE_TO_MASK[strobe];
	res = (cur_data & (~mask))+(data & mask);
    buffer[index][position][offset] = res;
    cur->dirty = 1;

    log_debug("ref: store(0x%x, %d, %x, \"%08x\")\n", addr, 1 << size, strobe, data);
}

void CacheRefModel::check_internal() {
    /**
     * TODO (Lab3) compare reference model's internal states to RTL model :)
     *
     * NOTE: you can use pointer top and scope to access internal signals
     *       in your RTL model, e.g., top->clk, scope->mem.
     */

    auto mem = reinterpret_cast<uint32_t (*)[4][WORDS_NUM]>(scope->top__DOT__data);
    for(int i = 0; i < SETS_NUM; ++i){
        for(int j = 0; j < 4; ++j){
            for(int k = 0; k < WORDS_NUM; ++k){
                asserts(
                    buffer[i][j][k] == mem[i][j][k],
                    "reference model's internal state is different from RTL model."
                    " at mem[%x][%x][%x], expected = %08x, got = %08x",
                    i, j, k, buffer[i][j][k], mem[i][j][k]
                );
            }
        }
    }

    log_debug("ref: check_internal()\n");

    /**
     * the following comes from StupidBuffer's reference model.
     */
    // for (int i = 0; i < 16; i++) {
    //     asserts(
    //         buffer[i] == scope->mem[i],
    //         "reference model's internal state is different from RTL model."
    //         " at mem[%x], expected = %08x, got = %08x",
    //         i, buffer[i], scope->mem[i]
    //     );
    // }
}

void CacheRefModel::check_memory() {
    /**
     * TODO (Lab3) compare reference model's memory to RTL model :)
     *
     * NOTE: you can use pointer top and scope to access internal signals
     *       in your RTL model, e.g., top->clk, scope->mem.
     *       you can use mem.dump() and MyCache::dump() to get the full contents
     *       of both memories.
     */

    log_debug("ref: check_memory()\n");

    /**
     * the following comes from StupidBuffer's reference model.
     */
    asserts(mem.dump(0, mem.size()) == top->dump(), "reference model's memory content is different from RTL model");
}
