`include "common.svh"

module DCache_to_ICache #(    
    parameter int OFFSET_BITS = 4,
    parameter int INDEX_BITS = 2,
    parameter int LINE_NUM = 4,

    localparam int TAG_BITS = 32 - OFFSET_BITS - INDEX_BITS,

    localparam int SET_NUM = 2 ** INDEX_BITS,
    localparam int BLOCK_NUM = 2 ** OFFSET_BITS,
    localparam int WORD_NUM = BLOCK_NUM / 4
    )(
    input logic clk, resetn,

    input  dbus_req_t  dreq,
    output dbus_resp_t dresp,
    output cbus_req_t  dcreq,
    input  cbus_resp_t dcresp
);

    typedef logic[INDEX_BITS-1:0] index_t;
    typedef logic[OFFSET_BITS-1:0] offset_t;
    typedef logic[TAG_BITS-1:0] tag_t;
    typedef i2 position_t;  // cache set 内部的下�?

    typedef struct packed { 
        tag_t tag;
        logic valid;  // cache line 是否有效�?
        logic dirty;  // cache line 是否被写入了�? now we need this
    } meta_t;

    //four lines in a set
    typedef meta_t [LINE_NUM-1:0] meta_set_t;

    typedef word_t [WORD_NUM-1:0] cache_line_t;
    typedef cache_line_t [LINE_NUM-1:0] cache_set_t;

    // 存储单元（寄存器�?
    meta_set_t [SET_NUM-1:0] meta, meta_nxt;
    cache_set_t [SET_NUM-1:0] data/* verilator public_flat_rd */, data_nxt;

    // 解析地址
    tag_t tag;
    index_t index;
    offset_t offset, offset_tmp;
    assign {tag, index, offset_tmp} = dreq.addr;
    assign offset = offset_tmp / 4;

    // 访问元数�?
    meta_set_t foo;
    assign foo = meta[index];

    // 搜索 cache line
    logic cache_hit_flag;
    position_t position;
    position_t[SET_NUM-1:0] replace_pos, replace_pos_nxt;
    always_comb begin
        position = 2'b00;  // 防止出现锁存�?
        cache_hit_flag = 0;
        unique if (foo[0].tag == tag && foo[0].valid) begin
            position = 2'b00;
            cache_hit_flag = 1;
        end else if (foo[1].tag == tag && foo[1].valid) begin
            position = 2'b01;
            cache_hit_flag = 1;
        end else if (foo[2].tag == tag && foo[2].valid) begin
            position = 2'b10;
            cache_hit_flag = 1;
        end else if (foo[3].tag == tag && foo[3].valid) begin
            position = 2'b11;
            cache_hit_flag = 1;
        end else begin end
    end

    //tag相同且valid
    //logic cache_hit_flag = (foo[position].tag == meta[index][position].tag && meta[index][position].valid);
    //读且命中 或�?? 写且写完�?
    logic valid; 
    assign valid = (dreq.strobe == '0 && cache_hit_flag) || (dreq.strobe != '0 && dcresp.last && dcresp.ready);
    
    //dresp
    word_t d_tmp;
    always_comb begin
        dresp = '0;
        d_tmp = '0;
        if (valid && dreq.valid) begin
            dresp.addr_ok = 1;
            dresp.data_ok = 1;
            d_tmp = data[index][position][offset];
            if (dreq.strobe == '0) begin
                unique case(dreq.size)
                    MSIZE2: begin
                        if (~dreq.addr[1]) begin
                            dresp.data = {16'd0, d_tmp[15:0]};
                        end else begin
                            dresp.data = {d_tmp[31:16], 16'd0};
                        end    
                    end

                    MSIZE1: begin
                        if (dreq.addr[1:0] == 2'b00) begin
                            dresp.data = {24'd0, d_tmp[7:0]};
                        end else if (dreq.addr[1:0] == 2'b01) begin
                            dresp.data = {16'd0, d_tmp[15:8], 8'd0};
                        end else if (dreq.addr[1:0] == 2'b10) begin
                            dresp.data = {8'd0, d_tmp[23:16], 16'd0};
                        end else if (dreq.addr[1:0] == 2'b11) begin
                            dresp.data = {d_tmp[31:24], 24'd0};
                        end
                    end

                    MSIZE4: dresp.data = d_tmp;
                    
                    default:begin end
                endcase
            end 
        end    
    end

    //so it's not used before definition
    logic valid_down_flag, valid_down_flag_nxt;
    //dcreq
    always_comb begin
        dcreq = '0;
        //读永远读�?个line，即4x4
        if (dreq.strobe == '0 && ~cache_hit_flag) begin
            dcreq.valid = 1;
            dcreq.is_write = 0;
            dcreq.size = MSIZE4;
            dcreq.addr = dreq.addr;
            dcreq.strobe = '0;
            dcreq.data = '0;
            dcreq.len = MLEN4;
        end else if(dreq.strobe != '0) begin
            dcreq.valid = 1;
            dcreq.is_write = 1;
            dcreq.size = dreq.size;
            dcreq.addr = dreq.addr;
            dcreq.strobe = dreq.strobe;
            dcreq.data = dreq.data;
            dcreq.len = MLEN1;
        end
        if (valid_down_flag) begin
            dcreq.valid = 0;
        end
        if (~dreq.valid) begin
            dcreq = '0;
        end
    end
    
    //记录传输的计数器
    logic[1:0] counter, counter_nxt, true_block, read_block;
    assign true_block = dreq.addr[3:2];
    //在ready last 握手时拉下valid
    assign valid_down_flag_nxt = dcresp.last && dcresp.ready ? 1 : 0;

    //data_nxt
    word_t tmp,ret,tmp_dat;
    logic[7:0] tmp1,tmp2,tmp3,tmp4;
    always_comb begin
        tmp = dreq.data;
        ret = '0;
        tmp_dat = data[index][position][true_block];;
        tmp1 = dreq.strobe[0] ? tmp[7:0] : 0; 
        tmp2 = dreq.strobe[1] ? tmp[15:8] : 0; 
        tmp3 = dreq.strobe[2] ? tmp[23:16] : 0; 
        tmp4 = dreq.strobe[3] ? tmp[31:24] : 0; 
        unique case (dreq.size)
            MSIZE4: begin
                ret = {tmp4, tmp3, tmp2, tmp1};  
            end

            MSIZE2: begin
                if (~dreq.addr[1]) begin
                    ret = {tmp_dat[31:16], tmp2, tmp1};
                end else begin
                    ret = {tmp4, tmp3, tmp_dat[15:0]};
                end    
            end

            MSIZE1: begin
                if (dreq.addr[1:0] == 2'b00) begin
                    ret = {tmp_dat[31:8], tmp1};
                end else if (dreq.addr[1:0] == 2'b01) begin
                    ret = {tmp_dat[31:16], tmp2, tmp_dat[7:0]};
                end else if (dreq.addr[1:0] == 2'b10) begin
                    ret = {tmp_dat[31:24], tmp3, tmp_dat[15:0]};
                end else if (dreq.addr[1:0] == 2'b11) begin
                    ret = {tmp4, tmp_dat[23:0]};
                end
            end

            default: begin
            end

        endcase
    end

    always_comb begin
        data_nxt = data; 
        meta_nxt = meta;
        counter_nxt = counter;
        read_block = true_block + counter;
        replace_pos_nxt = replace_pos;
        if (dreq.strobe == '0 && ~cache_hit_flag && dcresp.ready) begin
            data_nxt[index][replace_pos[index]][read_block] = dcresp.data;
            counter_nxt = counter + 1;
            if (dcresp.last) begin
                meta_nxt[index][replace_pos[index]].valid = 1;
                meta_nxt[index][replace_pos[index]].tag = tag;
                counter_nxt = '0;
                replace_pos_nxt[index] = replace_pos[index] + 1;
            end
        end else if(dreq.strobe != '0 && cache_hit_flag) begin
            data_nxt[index][position][true_block] = ret;
        end
    end

    always_ff @(posedge clk) begin
        if (~resetn) begin
            data <= '0;
            meta <='0;
            counter <= '0;
            replace_pos <= '0;
            valid_down_flag <= 0;
        end else begin
            data <= data_nxt;
            meta <= meta_nxt;
            counter <= counter_nxt;
            valid_down_flag <= valid_down_flag_nxt;
            replace_pos <= replace_pos_nxt;
        end
     end

    //assign bar = data[index][position];
    //assign dcreq.data = bar[offset[5:2]];  //4 字节对齐 

    // remove following lines when you start
    //assign {dresp, dcreq} = '0;
endmodule
