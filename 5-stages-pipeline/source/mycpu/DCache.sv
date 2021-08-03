`include "common.svh"
//`include "Myheadfile.svh"

module DCache #(
    parameter int OFFSET_BITS = 4,
    parameter int INDEX_BITS = 7,
    //4路缓存
    localparam int TAG_BITS = 32 - OFFSET_BITS - INDEX_BITS,
    localparam int WORDS_NUM = 1 << (OFFSET_BITS-2),   
    localparam int SETS_NUM = 1 << INDEX_BITS
    //localparam int 
) (
    input logic clk, resetn,

    input  dbus_req_t  dreq,
    output dbus_resp_t dresp,
    output cbus_req_t  creq,
    input  cbus_resp_t cresp,
    input i1 uncachedD
);
//typedef
    typedef enum i3 {
        BLANK,
        INVALID,
        FETCH,
        VALID,
        DIRTY,
        READY
    } state_t;

    typedef logic[TAG_BITS-1:0] tag_t;
    typedef logic[INDEX_BITS-1:0] index_t;
    typedef logic[OFFSET_BITS-3:0] offset_t;   //4字节对齐
    typedef i2 position_t;  // cache set 内部的下标，4路缓存

    typedef struct packed {
        tag_t tag;
        logic valid;  // cache line 是否有效？
        logic dirty;  // cache line 是否被写入了？
    } meta_t;
    typedef meta_t [3:0] meta_set_t;     //[3:0]是指4路缓存

    typedef word_t [WORDS_NUM-1:0] cache_line_t;   //根据offset获取的字节数目,
    typedef cache_line_t [3:0] cache_set_t;     

//statement
    state_t state;
    dbus_req_t req;
    offset_t start;
    // 存储单元（寄存器）
    /* verilator lint_off UNDRIVEN */
    meta_set_t [SETS_NUM-1:0] meta, meta_nxt;
    cache_set_t [SETS_NUM-1:0] data /* verilator public_flat_rd */, data_nxt;
    /* verilator lint_on UNDRIVEN */

    // 解析地址
    tag_t tag;
    index_t index;
    offset_t offset;
    assign {tag, index} = dreq.addr[31:OFFSET_BITS];  //4字节对齐
    assign start = dreq.addr[OFFSET_BITS-1:2];

    // 搜索 cache line  4路缓存
    meta_set_t foo;
    assign foo = meta[index];

    position_t position;
    i1 EXI, MISS;
    always_comb begin
        //position = 2'b00;  // 防止出现锁存器
        EXI = 1;
        if (foo[0].tag == tag)
            position = 2'b00;
        else if (foo[1].tag == tag)
            position = 2'b01;
        else if (foo[2].tag == tag)
            position = 2'b10;
        else if (foo[3].tag == tag)
            position = 2'b11;
        else begin   //没有相同的tag
            EXI = 0;
            if(!foo[0].valid) position = 2'b00;
            else if(!foo[1].valid) position = 2'b01;
            else if(!foo[2].valid) position = 2'b10;
            else if(!foo[3].valid) position = 2'b11;
            else position = tag[1:0];  //随机替换策略
        end         
    end
    assign MISS = ~(EXI & foo[position].valid);  //tag相同且是valid才算命中
    
    // 访问 cache line
    i32 cache_data;
    cache_line_t bar;
    assign bar = data[index][position];
    assign cache_data = bar[offset];  // 4 字节对齐 把地址所在的字全部给出
    
    // 访问对应行的元数据
	tag_t tag_nxt;
    meta_t meta_data;
    assign meta_data = foo[position];
    
    // CBus driver
    always_comb begin
        if(!uncachedD)begin
            creq.valid    = state == FETCH || state == DIRTY;
            creq.is_write = state == DIRTY;
            creq.size     = MSIZE4;
            creq.addr     = req.addr;
            creq.strobe   = 4'b1111;
            creq.data     = cache_data;
            creq.len      = MLEN4;  //WORDS_NUM            
        end else begin
            creq.valid    =  dreq.valid;
            creq.is_write = |dreq.strobe;
            creq.size     =  dreq.size;
            creq.addr     =  dreq.addr;
            creq.strobe   =  dreq.strobe;
            creq.data     =  dreq.data;
            creq.len      =  MLEN1;
        end
    end

    i1 okay, okey;
    assign okay = cresp.ready && cresp.last;
    assign okey = state == READY;
    always_comb begin
        if(!uncachedD)begin
            dresp = {okey, okey, cache_data};
        end else begin
            dresp  = {okay, okay, cresp.data};
        end
    end

    i1 is_dirty;
    //write back
    /* verilator lint_off WIDTHCONCAT */
    always_ff @(posedge clk) begin
        if(~resetn)begin
            meta <= '0;
            data <= '0;
        end else begin
            meta <= meta_nxt;
            data <= data_nxt;
        end
    end
    /* verilator lint_on WIDTHCONCAT */

    for(genvar i = 0; i < SETS_NUM; ++i)begin
        for(genvar j = 0; j < 4; ++j)begin   //4路缓存
            for(genvar k = 0; k < WORDS_NUM; ++k)begin
                always_comb begin
                    data_nxt[i][j][k] = data[i][j][k];
                    if(index == i && position == j && offset == k)begin
                        if(state == FETCH) begin
                            data_nxt[i][j][k] = cresp.data;
                        end else if(state != BLANK && state != DIRTY && (|req.strobe))begin
                            if(req.strobe[0])data_nxt[i][j][k][7:0] = req.data[7:0];
                            if(req.strobe[1])data_nxt[i][j][k][15:8] = req.data[15:8];
                            if(req.strobe[2])data_nxt[i][j][k][23:16] = req.data[23:16];
                            if(req.strobe[3])data_nxt[i][j][k][31:24] = req.data[31:24];
                        end
                    end
                end
            end
            always_comb begin
                meta_nxt[i][j] = meta[i][j];
                if(index == i && position == j && state != BLANK && state != DIRTY)begin
                    meta_nxt[i][j] = {tag, 1'b1, is_dirty};
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            state <= BLANK;
            //{dresp, req} <= '0;
            req <= '0;
            offset <= '0;
            is_dirty <= '0;
        end else begin
            unique case (state)
                BLANK: 
                    if(dreq.valid)begin
                        if(!uncachedD)begin
                            state  <= MISS ? (meta_data.dirty ? DIRTY : INVALID) : VALID; //没有脏就直接取值
                        //offset <= dreq.addr[:2];
                            offset <= start;                                     //可能会写回dirty的数据，所以需要offset
                            req.addr <= {meta_data.tag, index, start, 2'b00};   //可能会写回dirty的数据，所以需要地址
                            {req.strobe, req.data} <= {dreq.strobe, dreq.data};
                            is_dirty <= meta_data.dirty | (|dreq.strobe);  
                            tag_nxt <= tag;
                        end
                    end

                READY: begin
                    state <= BLANK;
                end

                INVALID: if(dreq.valid && !uncachedD)begin
                    state  <= FETCH;
                    req    <= dreq;
					tag_nxt <= tag;
                    offset <= start;
                end

                FETCH: if(cresp.ready) begin
                    state  <= cresp.last ? VALID : FETCH;
                    offset <= offset + 1;
                    is_dirty <= meta_data.dirty | (|req.strobe);
                end

                VALID: begin
                    state <= READY;
                end

                DIRTY: if(cresp.ready) begin
                    state  <= cresp.last ? INVALID : DIRTY;
                    offset <= offset + 1;
                end
                default: state <= BLANK;
            endcase
        end
    end
    
    //`UNUSED_OK({clk, resetn, dreq, cresp});
    
    logic _unused_ok = &{1'b0, meta_nxt, data_nxt, meta_data, req, tag_nxt,1'b0};
    //logic _undriven_ok = &{1'b0, meta_nxt, data_nxt, 1'b0};
endmodule
