`include "common.svh"
`include "instr.svh"

module ICache_final(
    input logic clk, resetn, i_uncached,

    //to cpu
    input ibus_req_t cache_ireq,
    output ibus_resp_t cache_iresp,
    input addr_t ireq_vaddr,

    //to crossbar
    input cbus_resp_t cbus_resp,
    output cbus_req_t cbus_req
);
    
    //VIPT
    index_t vaddr_index, paddr_index;
    tag_t vaddr_tag, paddr_tag;

    assign vaddr_index = ireq_vaddr[`ICache_offset_bit + `ICache_index_bit -1 :`ICache_offset_bit];
    assign paddr_tag = cache_ireq.addr[31:`ICache_index_bit + `ICache_offset_bit];



    meta_set_t ram_meta; 
    data_set_t bram_out_cacheset;

    index_t lutram_replace_index;
    meta_set_t ram_new_meta;

    register_t register, register_nxt;
    
    logic miss_to_hit_flag;

   
    
    I_LUTRAM #(
        .DATA_WIDTH($bits(meta_set_t)),
        .ADDR_WIDTH(`ICache_index_bit),
        .ENABLE_BYTE_WRITE(0)
    ) meta_inst(
        .clk(clk),
        .write_en((register.state == MISS && miss_to_hit_flag == 0) ? 1 :0),
        .addr((register.state == MISS && miss_to_hit_flag == 0) ? lutram_replace_index : vaddr_index),//TODO),
        .data_in(ram_new_meta),
        .data_out(ram_meta)
    );


    // Stage 1: hit test and LRU function

    state_t state;
    capacity_t capacity;
    position_t hit_pos, available_pos;
    logic first_available_flag;


    LRU_func_t LRU_func;
    position_t LRU_modify_pos, LRU_replace_pos;


    always_comb begin
        if(~i_uncached) begin
            state = MISS;
            capacity = AVAILABLE;
            first_available_flag = 0;
            hit_pos = '0;
            available_pos = '0;
            LRU_func = MODIFY;
            LRU_modify_pos = '0;
            LRU_replace_pos = '0;
            
            for(int i = 0; i < ASSOCIATIVITY; i++) begin
                if(ram_meta[i[`ICache_position_bit-1:0]].valid && paddr_tag == ram_meta[i[`ICache_position_bit-1:0]].tag) begin//hit
                    state = HIT;
                    hit_pos = i[`ICache_position_bit-1:0];

                    LRU_func = MODIFY;
                    LRU_modify_pos = hit_pos;
                    
                    break;
                end else if (~ram_meta[i].valid && first_available_flag == 0) begin//miss but avai
                    available_pos = i[`ICache_position_bit-1:0];
                    LRU_func = MODIFY;

                    first_available_flag = 1;

                    LRU_modify_pos = available_pos;
                    
                end else if(first_available_flag == 0) begin //miss and full
                    capacity = FULL;

                    LRU_func = REPLACE;
                    LRU_modify_pos = '0;

                end else begin
                    //nothing
                end
            end
        end else begin
            //uncached
        end
    end


    LRU LRU_inst(
        .resetn(resetn),
        .not_funct_en(register.state == MISS && miss_to_hit_flag == 0),
        .func(LRU_func),
        .index(vaddr_index),
        .hit_pos(LRU_modify_pos),
        .LRU_pos(LRU_replace_pos)
    );


    cacheline_t the_missed_cacheline, the_missed_cacheline_nxt;
    logic tag, tag_nxt;

    //register handling
    always_comb begin
        if(~i_uncached) begin
            if(register.state == MISS && miss_to_hit_flag == 0) begin
                register_nxt = register;
            end else begin
                register_nxt = '0;
                the_missed_cacheline_nxt = '0;
                tag_nxt = 0;
                if (cache_ireq.valid) begin
                    if(cache_ireq.addr[1:0] == 2'b00) begin
                        register_nxt.addr_ok = 1;
                        register_nxt.ireq = cache_ireq;
                        register_nxt.index = vaddr_index;

                        if(state == HIT) begin //hit
                            register_nxt.state = HIT;
                            register_nxt.pos = hit_pos;
                        end else begin //miss
                            register_nxt.state = MISS;
                            register_nxt.capacity = capacity;
                            register_nxt.pos = (capacity == FULL) ? LRU_replace_pos : available_pos;
                        end

                    end else begin//addr is not ok
                        //register_nxt.addr_ok = 0;
                    end
                end
            end
        end else begin
            //uncached
        end
    end


    // Stage 2: miss handling and data return

    logic bram_replace_en;
    index_t bram_replace_index;

    data_set_t bram_replace_cacheset, bram_useless_cachesetni;

    


    //miss handle 如果miss 则发请求发整整一个cacheline的请??? 也就???8个字???2条指令请???
    always_comb begin
        the_missed_cacheline_nxt = the_missed_cacheline;
        if(~i_uncached) begin
            miss_to_hit_flag = 0;

            //tag_nxt = tag;
            the_missed_cacheline_nxt = the_missed_cacheline;

            if(register.state == MISS && cbus_req.valid) begin
                if(cbus_resp.ready) begin
                    the_missed_cacheline_nxt[tag] = cbus_resp.data;
                    tag_nxt = tag + 1;
                    if(cbus_resp.last) begin
                        miss_to_hit_flag = 1;

                        lutram_replace_index = register.index;
                        
                        bram_replace_en = 1;
                        bram_replace_index = register.index;

                        cbus_req_nxt = '0;
    
                        cache_iresp_nxt.addr_ok = 1;
                        cache_iresp_nxt.data_ok = 1;
                        cache_iresp_nxt.data = the_missed_cacheline_nxt;

                        if(register.capacity == AVAILABLE) begin //avail
                            ram_new_meta[register.pos.available_pos].tag = paddr_tag;
                            ram_new_meta[register.pos.available_pos].valid = 1;
                            bram_replace_cacheset[register.pos.available_pos] = the_missed_cacheline_nxt;
                        end else begin //full
                            ram_new_meta[register.pos.replace_pos].valid = 1;
                            ram_new_meta[register.pos.replace_pos].tag = paddr_tag;
                            bram_replace_cacheset[register.pos.replace_pos] = the_missed_cacheline_nxt;
                        end
                    end
                end
                
            end else begin //hit
                //cache_iresp.data = bram_out_cacheset[hit_pos];
                bram_replace_en = 0;
                bram_replace_index = '0;
                bram_replace_cacheset = '0;

                lutram_replace_index = '0;
                ram_new_meta = '0;
            end
        end else begin
            //uncached
        end
    end

    

    /*
        port 1 is for read only;
        port 2 is for miss replacement.
    */
    I_BRAM #(
        .DATA_WIDTH($bits(data_set_t)),
        .ADDR_WIDTH(`ICache_index_bit),
        .WRITE_MODE("read_first")
    ) data_inst(
        .clk(clk),
        .reset(~resetn),

        .en_1(1),
        .write_en_1(0),
        .addr_1(vaddr_index), //TODO: check whether this is right? register.index instead?
        .data_in_1('0),
        .data_out_1(bram_out_cacheset),

        .en_2(1),
        .write_en_2(bram_replace_en),
        .addr_2(bram_replace_index),
        .data_in_2(bram_replace_cacheset),
        .data_out_2(bram_useless_cacheset)
    );


    always_ff @(posedge clk) begin
        if(resetn) begin
            register <= register_nxt;
            tag <= tag_nxt;
            the_missed_cacheline <= the_missed_cacheline_nxt;
        end else begin
            register <= '0;
            tag <= '0;
            the_missed_cacheline <= '0;
        end
    end

    //bus drivers
    ibus_resp_t cache_iresp_nxt;
    cbus_req_t cbus_req_nxt;



    always_comb begin
        if(i_uncached) begin
            cbus_req_nxt.valid = cache_ireq.valid;
            cbus_req_nxt.is_write = 0;
            cbus_req_nxt.size = MSIZE4;
            cbus_req_nxt.strobe = 4'b0;
            cbus_req_nxt.data = '0;
            cbus_req_nxt.addr = {cache_ireq.addr[31:3], 3'b0};
            cbus_req_nxt.len = MLEN2; 

            if(cache_ireq.valid && cbus_resp.ready) begin
                the_missed_cacheline_nxt[tag] = cbus_resp.data;
                tag_nxt = tag + 1;
                if(cbus_resp.last) begin
                    cache_iresp_nxt.addr_ok = 1;
                    cache_iresp_nxt.data_ok = 1;
                    cache_iresp_nxt.data = the_missed_cacheline_nxt;
                    //cache_iresp_nxt.predecode_rslt = '0;
                end
            end

        end else begin
            /*if(miss_to_hit_flag == 1) begin
                cbus_req_nxt = '0;
    
                cache_iresp_nxt.addr_ok = 1;
                cache_iresp_nxt.data_ok = 1;
                cache_iresp_nxt.data = the_missed_cacheline_nxt;
                //cache_iresp_nxt.predecode_rslt = '0;
            end else begin*/
                if(register.state == HIT) begin
                    cbus_req_nxt = '0;
        
                    cache_iresp_nxt.addr_ok = 1;
                    cache_iresp_nxt.data_ok = 1;
                    cache_iresp_nxt.data = bram_out_cacheset[hit_pos];
                    //cache_iresp_nxt.predecode_rslt = '0;
                end else begin
                    cbus_req_nxt.valid = 1;
                    cbus_req_nxt.is_write = 0;
                    cbus_req_nxt.size = MSIZE4;
                    cbus_req_nxt.strobe = 4'b0;
                    cbus_req_nxt.data = '0;
                    //cbus_req_nxt.addr = register.ireq.addr;
                    cbus_req_nxt.addr = (register.ireq.addr[2] == 1) ? {register.ireq.addr[31:3], 3'b0} : {register.ireq.addr};
                    cbus_req_nxt.len = MLEN2;//TODO: to be checked for one cacheline
        
                    cache_iresp_nxt = '0;
                end
            //end
            
        end
    end
    
    //predecode
    always_comb begin
        for(int i = 0; i < INSTR_SIZE; i++) begin
                if(cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000100 || //beq
                    cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000101 || //bne
                    cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000110 || //blez
                    cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000111 || //bgtz
                    cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000010 || //j
                    cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000000 && cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][5:0]   == 6'b001001 || //jalr
                    cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000001 && cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][20:16] == 5'b00001  || //bgez
                    cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000001 && cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][20:16] == 5'b10001  || //bgezal
                    cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000001 && cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][20:16] == 5'b00000  || //bltz
                    cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000001 && cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][20:16] == 5'b10010     //bltzal
                   ) begin //is_branch
                    cache_iresp_nxt.predecode[i[INSTR_SIZE-1:0]] = is_branch;
                end else if (cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000000 &&
                            cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][25:21] == 5'b11111  &&
                            cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][5:0]   == 6'b001000
                             ) begin //is_ret jr ra
                    cache_iresp_nxt.predecode[i[INSTR_SIZE-1:0]] = is_ret;
                end else if (cache_iresp_nxt.data[i[INSTR_SIZE-1:0]][31:26] == 6'b000011) begin //is_call jal
                             cache_iresp_nxt.predecode[i[INSTR_SIZE-1:0]] = is_call;
                end else begin //normal
                    cache_iresp_nxt.predecode[i[INSTR_SIZE-1:0]] = normal;
                end
            end
    end

    assign cache_iresp = cache_iresp_nxt;
    assign cbus_req = cbus_req_nxt;


endmodule