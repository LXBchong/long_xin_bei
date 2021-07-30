`include "def.svh"

`define INVALID 3'b000
`define VALID   3'b001
`define DIRTY   3'b010
`define READING 3'b011
`define WRITING 3'b100
`define DONE    3'b101

module Dache(
    input logic clk,resetn,d_uncached,
    input dbus_req_t cache_dreq,
    output dbus_resp_t cache_dresp,

    output cbus_req_t dcreq,
    input cbus_resp_t dcresp
);

logic [3:0] meta_addr,data_raddr,data_waddr;
logic [3:0] meta_addr_one,meta_addr_two;
logic [3:0] data_raddr_one,data_raddr_two;
logic [3:0] data_waddr_two;


logic [3:0] meta_strobe,meta_strobe_two;
logic [15:0] data_strobe,data_strobe_two; 

word_t r_meta,w_meta,w_meta_two;

typedef logic [2:0] LRU_tag;
LRU_tag [Dcache_set_num-1:0] LRU;

LRU_tag new_LRU_tag;


logic [Dcache_tag_bits-1:0] tag,tag_two;
logic [Dcache_offset_len -1:0] offset,offset_two;
logic [Dcache_set_len-1:0] index,index_two;

logic hit_one,hit_two;

dbus_req_t dreq_two;

logic [Dcache_set_len-1:0] position_one;

logic stall_one,stall_two,resp_ok,step_two_ok,uncached_two;

logic last_pass;  // a new request go to step_two this cycle

word_t [Dcacheline_len-1:0] data_reg,new_data,current_data,
                            w_data,r_data,w_data_two;

word_t new_word;

logic [2:0] state_two,new_state_two;

logic wb_addr,last_wb_addr;

LUTRAM  D_meta(.clk(clk),
            .addr(meta_addr),
            .strobe(meta_strobe),
            .wdata(w_meta),
            .rdata(r_meta));

BRAM    D_data(.clk(clk),
            .reset(~resetn),
            .write_en(data_strobe),
            .raddr(data_raddr),
            .waddr(data_waddr),
            .wdata(w_data),
            .rdata(r_data));


assign {tag,index,offset} = cache_dreq.addr;
assign {tag_two,index_two,offset_two} = dreq_two.addr;

//ram signal
assign meta_addr    = stall_two ? meta_addr_two : meta_addr_one;
assign data_raddr   = stall_two ? data_raddr_two:data_raddr_one;
assign data_waddr   = stall_two ? data_waddr_two:'0;
assign w_meta       = stall_two ? w_meta_two:'0;
assign w_data       = stall_two ? w_data_two:'0;
assign meta_strobe  = stall_two ? meta_strobe_two:'0;
assign data_strobe  = stall_two ? data_strobe_two:'0;


//control logic
assign stall_two = dreq_two.valid & (~step_two_ok);
assign stall_one = stall_two;

assign cache_dresp.data_ok  = resp_ok;
assign cache_dresp.data     = uncached_two? dcresp.data:new_data[offset_two[Dcache_offset_len-1:2]];

assign current_data = last_pass?r_data:data_reg;


//step one
always_comb begin
    hit_one = '0;
    position_one = '0;
    new_LRU_tag = '0;
    for(int i=0;i<4;i++)begin
        
        meta_addr_one = {index,2'b00}+i;

        if( tag == r_meta[Dcache_tag_bits-1:0] ) begin 
            hit_one=1'b1;
            position_one = i;
            break;
        end
    end

    if(~hit_one) begin
        priority case(LRU[index])
            3'b000: begin
                position_one    = 2'b00;  
                new_LRU_tag     = 3'b110;
            end
            3'b001: begin
                position_one    = 2'b00;  
                new_LRU_tag     = 3'b111;
            end
            3'b010: begin 
                position_one    = 2'b01;  
                new_LRU_tag     = 3'b100;
            end
            3'b011: begin 
                position_one    = 2'b01;  
                new_LRU_tag     = 3'b101;
            end
            3'b100: begin 
                position_one    = 2'b10;  
                new_LRU_tag     = 3'b001;
            end
            3'b101: begin 
                position_one    = 2'b11;  
                new_LRU_tag     = 3'b000;
            end
            3'b110: begin 
                position_one    = 2'b10;  
                new_LRU_tag     = 3'b011;
            end
            3'b111: begin 
                position_one    = 2'b11;  
                new_LRU_tag     = 3'b010;
            end
            default:begin
                position_one    = '0;  
                new_LRU_tag     = '0;
            end
        endcase
    end

    meta_addr_one   = {index,2'b00}+position_one;
    data_raddr_one  = {index,2'b00}+position_one;
end



//step two

always_comb begin

dcreq.valid     = '0;
dcreq.is_write  = '0;
dcreq.size      = '0;
dcreq.addr      = '0;
dcreq.strobe    = '0;
dcreq.data      = '0;
dcreq.len       = '0;

new_state_two   = DONE;
resp_ok         ='0;
data_strobe_two ='0;
meta_strobe_two ='0;
w_data_two      ='0;
w_meta_two      ='0;
new_word        ='0;
new_data        ='0;
last_wb_addr    ='0;

if(dreq_two.valid & ~uncached_two)begin
    if(hit_two) begin

    new_hit_two     = 1'b1;
    unique case(state_two)

        INVALID:begin  
            new_state_two=READING
            //read from memory
            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b0;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {dreq_two.addr[31:4],4'b0};
            dcreq.strobe   = 4'b0;
            dcreq.data     = '0;
            dcreq.len      = MLEN4;
            
        end
        VALID:begin
            resp_ok=1'b1;
            if(dreq_two.is_write)begin
                new_state_two   = DONE;

                data_strobe_two = 16'hffff;
                meta_strobe_two = 4'b1111;

                w_data_two      = new_data;
                w_meta_two      = {DIRTY,'0,tag_two};

                new_word[7:0]  =dreq_two.strobe[0]?dreq_two.data[7:0]  :current_data[offset_two[Dcache_offset_len-1:2]][7:0];
                new_word[15:8] =dreq_two.strobe[1]?dreq_two.data[15:8] :current_data[offset_two[Dcache_offset_len-1:2]][15:8];
                new_word[23:16]=dreq_two.strobe[2]?dreq_two.data[23:16]:current_data[offset_two[Dcache_offset_len-1:2]][23:16];
                new_word[31:24]=dreq_two.strobe[3]?dreq_two.data[31:24]:current_data[offset_two[Dcache_offset_len-1:2]][31:24];

                unique case(offset_two[Dcache_offset_len-1:2])
                    2'b00:begin
                        new_data={current_data[127:32],new_word};
                    end
                    2'b01:begin
                        new_data={current_data[127:64],new_word,current_data[31:0]};
                    end
                    2'b10:begin
                        new_data={current_data[127:96],new_word,current_data[63:0]};
                    end
                    2'b11:begin
                        new_data={new_word,current_data[95:0]};
                    end
                    default:begin
                        new_data='0;
                    end
                endcase
            end
        end
        DIRTY:begin
            resp_ok=1'b1;
            if(dreq_two.is_write)begin

                new_state_two   = DIRTY;

                data_strobe_two = 16'hffff;
                meta_strobe_two = 4'b1111;

                w_data_two      = new_data;
                w_meta_two      = {DIRTY,'0,tag_two};

                new_word[7:0]  =dreq_two.strobe[0]?dreq_two.data[7:0]  :current_data[offset_two[Dcache_offset_len-1:2]][7:0];
                new_word[15:8] =dreq_two.strobe[1]?dreq_two.data[15:8] :current_data[offset_two[Dcache_offset_len-1:2]][15:8];
                new_word[23:16]=dreq_two.strobe[2]?dreq_two.data[23:16]:current_data[offset_two[Dcache_offset_len-1:2]][23:16];
                new_word[31:24]=dreq_two.strobe[3]?dreq_two.data[31:24]:current_data[offset_two[Dcache_offset_len-1:2]][31:24];

                unique case(offset_two[Dcache_offset_len-1:2])
                    2'b00:begin
                        new_data={current_data[127:32],new_word};
                    end
                    2'b01:begin
                        new_data={current_data[127:64],new_word,current_data[31:0]};
                    end
                    2'b10:begin
                        new_data={current_data[127:96],new_word,current_data[63:0]};
                    end
                    2'b11:begin
                        new_data={new_word,current_data[95:0]};
                    end
                    default:begin
                        new_data=current_data;
                    end
                endcase
            end
        end
        READING:begin //wait
            if(dcresp.ready)begin
                new_word = dresp.data;
                unique case (r_count)
                    4'h0:begin
                        new_data={current_data[127:32],new_word};
                    end
                    4'h1:begin
                        new_data={current_data[127:64],new_word,current_data[31:0]};
                    end
                    4'h2:begin
                        new_data={current_data[127:96],new_word,current_data[63:0]};
                    end
                    4'h3:begin
                        new_data={new_word,current_data[95:0]};
                    end
                    default:begin
                        new_data=current_data;
                    end
                endcase
            end
            else begin
                new_word='0;
                new_data=current_data;
            end

            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b0;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {dreq_two.addr[31:4],4'b0};
            dcreq.strobe   = 4'b0;
            dcreq.data     = '0;
            dcreq.len      = MLEN4;

            if(dcresp.last) new_state_two = VALID;
            else new_state_two = READING;

        end
        WRITING:begin

            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b1;
            dcreq.size     = MSIZE4;
            dcreq.addr     = wb_addr;
            dcreq.strobe   = 4'b1111;
            dcreq.data     = current_data[w_count];
            dcreq.len      = MLEN4;

            if(dcresp.last) new_state_two = INVALID;
            else new_state_two = WRITING;

            last_wb_addr = dcreq.addr;
        end
        DONE:begin
            step_two_ok=1'b1;

            dcreq.valid    = '0;
            dcreq.is_write = '0;
            dcreq.size     = '0;
            dcreq.addr     = '0;
            dcreq.strobe   = '0;
            dcreq.data     = '0;
            dcreq.len      = '0;
        end
        default:begin
            new_data='0;
            new_word='0;
        end
    endcase
    end
    else begin
        dcreq.valid    = 1'b0;
        dcreq.is_write = 1'b0;
        dcreq.size     = MSIZE4;
        dcreq.addr     = {dreq_two.addr[31:4],4'b0};
        dcreq.strobe   = 4'b0;
        dcreq.data     = '0;
        dcreq.len      = MLEN4;

        unique case(state_two)
        INVALID:begin
            new_hit_two=1'b1;
            new_state_two=READING;
            //read from memeory
            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b0;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {dreq_two.addr[31:4],4'b0};
            dcreq.strobe   = 4'b0;
            dcreq.data     = '0;
            dcreq.len      = MLEN4;
        end

        VALID:begin
            new_hit_two = 1'b1;
            new_state_two = READING;
            //read from memeory
            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b0;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {dreq_two.addr[31:4],4'b0};
            dcreq.strobe   = 4'b0;
            dcreq.data     = '0;
            dcreq.len      = MLEN4;
        end

        DIRTY:begin
            new_hit_two = 1'b1;
            new_state_two = WRITING;
            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b1;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {meta_two[Dcache_tag_bits-1:0],dreq_two.addr[5:4],4'b0};
            dcreq.strobe   = 4'b1111;
            dcreq.data     = current_data[w_count];
            dcreq.len      = MLEN4;

            last_wb_addr = {meta_two[Dcache_tag_bits-1:0],dreq_two.addr[5:4],4'b0};
        end
        default:begin
            new_state_two=state_two;
            new_hit_two=1'b0;
        end
        endcase             
    end
end
else if(dreq_two.valid & uncached_two)begin
    new_state_two   = state_two;
    new_data        = current_data;
    new_hit_two     = 1'b0;
    last_wb_addr    = '0;

    if(dcresp.last) resp_ok= 1'b1;
    else resp_ok    = 1'b0;

    dcreq.valid     = 1'b1;
    dcreq.is_write  = dreq_two.is_write;
    dcreq.size      = dreq_two.size;
    dcreq.addr      = dreq_two.addr;
    dcreq.strobe    = dreq_two.strobe;
    dcreq.data      = dreq_two.data;
    dcreq.len       = MLEN1;
end
else begin
    new_state_two   = state_two;
    new_data        = current_data;
    new_hit_two     = 1'b0;
    last_wb_addr    = '0;

    dcreq.valid     = '0
    dcreq.is_write  = '0
    dcreq.size      = '0
    dcreq.addr      = '0
    dcreq.strobe    = '0
    dcreq.data      = '0
    dcreq.len       = '0
end
end




always_ff @(posedge clk) begin
    if(resetn)begin
        if(~stall_one) begin
            last_pass   <=1'b1;

            if(cache_dreq.valid) cache_dresp.addr_ok<=1'b1;

            dreq_two    <=cache_dreq;
            uncached_two<=d_uncached;
            hit_two     <=hit_one;
            meta_two    <=r_meta;
            state_two   <=r_meta[31:29];

            meta_addr_two   <=meta_addr_one;
            data_raddr_two  <=data_raddr_one;
            data_waddr_two  <=data_raddr_one;

            LRU[index]      <=new_LRU_tag;
        end
        else begin
            last_pass   <=1'b0;
            cache_dresp.addr_ok <=1'b0;
        end


        if(stall_two)begin
            data_reg    <=new_data;
            hit_two     <=new_hit_two;
            state_two   <=new_state_two;

            if(dcreq.valid && ~dcreq.is_write && dcresp.ready ) r_count <= r_count + 1;
            else if(dcreq.valid && ~dcreq.is_write) ;
            else r_count<='0;

            if(dcreq.valid && dcreq.is_write && dcresp.ready ) w_count <= w_count + 1;
            else if(dcreq.valid && dcreq.is_write) ;
            else w_count<='0;

            if(new_state_two == WRITING) wb_addr<=last_wb_addr;
            else wb_addr <='0;
        end
        else begin
            data_reg    <='0;
            hit_two     <='0;
            state_two   <='0;
            r_count     <='0;
            w_count     <='0;
            wb_addr     <='0;
        end

    end
    else begin
        LRU<='0;
    end
end


endmodule
