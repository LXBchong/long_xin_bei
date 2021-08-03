`include "dfs.svh"


module DCache(
    input logic clk,resetn,d_uncached,
    input dbus_req_t cache_dreq,
    output dbus_resp_t cache_dresp,

    output cbus_req_t dcreq,
    input cbus_resp_t dcresp
);

logic [Dcache_index_bits-1:0] meta_addr,data_raddr,data_waddr;
logic [Dcache_index_bits-1:0] meta_addr_one,meta_addr_two;
logic [Dcache_index_bits-1:0] data_raddr_one,data_raddr_two;
logic [Dcache_index_bits-1:0] data_waddr_two;

logic is_write;


logic [16:0] meta_strobe,meta_strobe_two;
logic [63:0] data_strobe,data_strobe_two; 

word_t [Dcacheline_len-1:0] r_meta,w_meta,w_meta_two,meta_two;

typedef logic [2:0] LRU_tag;
LRU_tag [Dcache_set_num-1:0] LRU;

LRU_tag new_LRU_tag;

logic [3:0] r_count,w_count;

logic [Dcache_tag_bits-1:0] tag,tag_two;
logic [Dcache_offset_bits -1:0] offset,offset_two;
logic [Dcache_index_bits-1:0] index,index_two;

dbus_req_t dreq_two;

logic just_hit,hit,new_hit,hit_reg;

logic [1:0] position,new_position,just_position,position_reg;

logic stall_one,stall_two,resp_ok,resp_addr_ok,step_two_ok,uncached_two;

logic last_pass;  // a new request go to step_two this cycle

typedef word_t[Dcacheline_len-1:0] line_t;

line_t[Dcache_way_num-1:0] w_data,r_data,w_data_two,
                    data_reg,new_data,current_data;

word_t new_word;

logic [2:0] state_two,new_state_two,state_two_reg;

logic[31:0] wb_addr,last_wb_addr;

D_LUTRAM  D_meta(.clk(clk),
            .resetn(resetn),
            .addr(meta_addr),
            .strobe(meta_strobe),
            .wdata(w_meta),
            .rdata(r_meta));

D_BRAM    D_data(.clk(clk),
            .reset(~resetn),
            .write_en(data_strobe),
            .raddr(data_raddr),
            .waddr(data_waddr),
            .wdata(w_data),
            .rdata(r_data));


assign is_write = dreq_two.strobe[0] | dreq_two.strobe[1] | dreq_two.strobe[2] | dreq_two.strobe[3] ;

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

assign cache_dresp.addr_ok  = resp_addr_ok;
assign cache_dresp.data_ok  = resp_ok;

assign cache_dresp.data     = uncached_two? 
dcresp.data : new_data[position][offset_two[Dcache_offset_bits-1:2]];

assign current_data     = last_pass?r_data:data_reg;

assign meta_addr_one    = index;
assign data_raddr_one   = index;
//step one

assign hit = last_pass? just_hit : hit_reg;
assign position = last_pass? just_position : position_reg;
assign state_two = last_pass?meta_two[position][31:29] : state_two_reg;


//hit or miss & LRU
always_comb begin
    just_hit = 1'b1;
    just_position = '0;
    new_LRU_tag = '0;
    
    priority case(tag_two)
        meta_two[0][Dcache_tag_bits-1:0]:just_position = 2'b00;
        meta_two[1][Dcache_tag_bits-1:0]:just_position = 2'b01;
        meta_two[2][Dcache_tag_bits-1:0]:just_position = 2'b10;
        meta_two[3][Dcache_tag_bits-1:0]:just_position = 2'b11;
        default: begin
            just_position=2'b0;
            just_hit=1'b0;
        end
    endcase

    if(~hit) begin
        priority case(LRU[index_two])
            3'b000: begin
                just_position   = 2'b00;  
                new_LRU_tag     = 3'b110;
            end
            3'b001: begin
                just_position   = 2'b00;  
                new_LRU_tag     = 3'b111;
            end
            3'b010: begin 
                just_position   = 2'b01;  
                new_LRU_tag     = 3'b100;
            end
            3'b011: begin 
                just_position   = 2'b01;  
                new_LRU_tag     = 3'b101;
            end
            3'b100: begin 
                just_position   = 2'b10;  
                new_LRU_tag     = 3'b001;
            end
            3'b101: begin 
                just_position   = 2'b11;  
                new_LRU_tag     = 3'b000;
            end
            3'b110: begin 
                just_position   = 2'b10;  
                new_LRU_tag     = 3'b011;
            end
            3'b111: begin 
                just_position   = 2'b11;  
                new_LRU_tag     = 3'b010;
            end
            default:begin
                just_position   = '0;  
                new_LRU_tag     = '0;
            end
        endcase
    end
end



//step two

always_comb begin

dcreq.valid     = '0;
dcreq.is_write  = '0;
dcreq.size      = MSIZE1;
dcreq.addr      = '0;
dcreq.strobe    = '0;
dcreq.data      = '0;
dcreq.len       = MLEN1;

new_state_two   = `DONE;
step_two_ok     = 1'b0;
resp_ok         ='0;
data_strobe_two ='0;
meta_strobe_two ='0;
w_data_two      =current_data;

new_word        ='0;
last_wb_addr    ='0;

w_meta_two      = meta_two;
new_position    = position;
new_data        = current_data;
new_hit         = '0;

if(dreq_two.valid & ~uncached_two)begin
    
    if(hit) begin

    new_hit     = 1'b1;
    unique case(state_two)

        `INVALID:begin  
            new_state_two=`READING;
            //read from memory
            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b0;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {dreq_two.addr[31:Dcache_offset_bits],'0};
            dcreq.strobe   = 4'b0;
            dcreq.data     = '0;
            dcreq.len      = MLEN4;
            
        end
        `VALID:begin
            resp_ok=1'b1;
            w_meta_two[position] = {`VALID,29'b0}+tag_two;
            if(is_write)begin

                new_state_two   = `DONE;

                data_strobe_two = 64'hffffffffffffffff;
                meta_strobe_two = 16'hffff;

                w_meta_two[position]    = {`DIRTY,29'b0}+tag_two;

                new_word[7:0]  =dreq_two.strobe[0]?dreq_two.data[7:0]  :current_data[position][offset_two[Dcache_offset_bits-1:2]][7:0];
                new_word[15:8] =dreq_two.strobe[1]?dreq_two.data[15:8] :current_data[position][offset_two[Dcache_offset_bits-1:2]][15:8];
                new_word[23:16]=dreq_two.strobe[2]?dreq_two.data[23:16]:current_data[position][offset_two[Dcache_offset_bits-1:2]][23:16];
                new_word[31:24]=dreq_two.strobe[3]?dreq_two.data[31:24]:current_data[position][offset_two[Dcache_offset_bits-1:2]][31:24];

                new_data[position][offset_two[Dcache_offset_bits-1:2]] = new_word;

                w_data_two = new_data;
            end
        end
        `DIRTY:begin
            resp_ok=1'b1;
            w_meta_two[position] = {`DIRTY,29'b0}+tag_two;
            if(is_write)begin        
                new_state_two   = `DONE;

                data_strobe_two = 64'hffffffffffffffff;
                meta_strobe_two = 16'hffff;

            
                w_meta_two[position]      = {`DIRTY,29'b0}+tag_two;

                new_word[7:0]  =dreq_two.strobe[0]?dreq_two.data[7:0]  :current_data[position][offset_two[Dcache_offset_bits-1:2]][7:0];
                new_word[15:8] =dreq_two.strobe[1]?dreq_two.data[15:8] :current_data[position][offset_two[Dcache_offset_bits-1:2]][15:8];
                new_word[23:16]=dreq_two.strobe[2]?dreq_two.data[23:16]:current_data[position][offset_two[Dcache_offset_bits-1:2]][23:16];
                new_word[31:24]=dreq_two.strobe[3]?dreq_two.data[31:24]:current_data[position][offset_two[Dcache_offset_bits-1:2]][31:24];

                new_data[position][offset_two[Dcache_offset_bits-1:2]] = new_word;
                w_data_two = new_data;

            end
        end
        `READING:begin //wait
            if(dcresp.ready)begin
                new_word = dcresp.data;
                new_data[position][r_count] = new_word;
            end
            else begin
                new_word='0;
                new_data=current_data;
            end

            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b0;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {dreq_two.addr[31:Dcache_offset_bits],'0};
            dcreq.strobe   = 4'b0;
            dcreq.data     = '0;
            dcreq.len      = MLEN4;

            if(dcresp.last) new_state_two = `VALID;
            else new_state_two = `READING;

        end
        `WRITING:begin

            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b1;
            dcreq.size     = MSIZE4;
            dcreq.addr     = wb_addr;
            dcreq.strobe   = 4'b1111;
            dcreq.data     = current_data[position][w_count];
            dcreq.len      = MLEN4;

            if(dcresp.last) new_state_two = `VALID;
            else new_state_two = `WRITING;

            last_wb_addr = dcreq.addr;
        end
        `DONE:begin
            step_two_ok=1'b1;

            dcreq.valid    = '0;
            dcreq.is_write = '0;
            dcreq.size     = MSIZE1;
            dcreq.addr     = '0;
            dcreq.strobe   = '0;
            dcreq.data     = '0;
            dcreq.len      = MLEN1;
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
        dcreq.addr     = {dreq_two.addr[31:Dcache_offset_bits],'0};
        dcreq.strobe   = 4'b0;
        dcreq.data     = '0;
        dcreq.len      = MLEN4;

        new_hit = 1'b1;

        unique case(state_two)
        `INVALID:begin
            new_state_two=`READING;
            //read from memeory
            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b0;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {dreq_two.addr[31:Dcache_offset_bits],'0};
            dcreq.strobe   = 4'b0;
            dcreq.data     = '0;
            dcreq.len      = MLEN4;
        end

        `VALID:begin
            new_state_two = `READING;
            //read from memeory
            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b0;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {dreq_two.addr[31:Dcache_offset_bits],'0};
            dcreq.strobe   = 4'b0;
            dcreq.data     = '0;
            dcreq.len      = MLEN4;
        end

        `DIRTY:begin
            new_state_two = `WRITING;
            dcreq.valid    = 1'b1;
            dcreq.is_write = 1'b1;
            dcreq.size     = MSIZE4;
            dcreq.addr     = {meta_two[position][Dcache_tag_bits-1:0],index_two,'0};
            dcreq.strobe   = 4'b1111;
            dcreq.data     = current_data[position][w_count];
            dcreq.len      = MLEN4;

            last_wb_addr = {meta_two[position][Dcache_tag_bits-1:0],index_two,'0};
        end
        default:begin
            new_state_two=`DONE;
            new_hit=1'b0;
        end
        endcase             
    end
end
else if(dreq_two.valid & uncached_two)begin
    new_state_two   = `DONE;
    new_data        = current_data;
    new_hit         = 1'b0;
    last_wb_addr    = '0;

    if(dcresp.last) begin 
        resp_ok     = 1'b1;
        step_two_ok = 1'b1;
    end
    else begin
        resp_ok     = 1'b0;
        step_two_ok = 1'b0;
    end

    dcreq.valid     = 1'b1;
    dcreq.is_write  = is_write;
    dcreq.size      = dreq_two.size;
    dcreq.addr      = dreq_two.addr;
    dcreq.strobe    = dreq_two.strobe;
    dcreq.data      = dreq_two.data;
    dcreq.len       = MLEN1;
end
else begin
    step_two_ok     = 1'b1;
    new_state_two   = `DONE;
    new_data        = current_data;
    new_hit         = 1'b0;
    last_wb_addr    = '0;

    dcreq.valid     = '0;
    dcreq.is_write  = '0;
    dcreq.size      = MSIZE1;
    dcreq.addr      = '0;
    dcreq.strobe    = '0;
    dcreq.data      = '0;
    dcreq.len       = MLEN1;
end
end


always_ff @(posedge clk) begin
    if(resetn)begin
        if(~stall_one) begin
            if(cache_dreq.valid) last_pass   <=1'b1;

            if(cache_dreq.valid) resp_addr_ok<=1'b1;

            dreq_two    <=cache_dreq;
            uncached_two<=d_uncached;
            meta_two    <=r_meta;

            meta_addr_two   <=meta_addr_one;
            data_raddr_two  <=data_raddr_one;
            data_waddr_two  <=data_raddr_one;        
        end



        if(stall_two)begin
            if(last_pass) LRU[index]    <=new_LRU_tag;

            data_reg        <=new_data;
            hit_reg         <=new_hit;
            position_reg    <=new_position;
            state_two_reg   <=new_state_two;
            
            last_pass       <=1'b0;
            resp_addr_ok    <=1'b0;

            if(dcreq.valid && ~dcreq.is_write && dcresp.ready ) r_count <= r_count + 1;
            else if(dcreq.valid && ~dcreq.is_write) ;
            else r_count<='0;

            if(dcreq.valid && dcreq.is_write && dcresp.ready ) w_count <= w_count + 1;
            else if(dcreq.valid && dcreq.is_write) ;
            else w_count<='0;

            if(new_state_two ==` WRITING) wb_addr<=last_wb_addr;
            else wb_addr <='0;
        end
        else begin
            data_reg        <='0;
            hit_reg         <='0;
            position_reg    <='0;
            state_two_reg   <='0;

            r_count     <='0;
            w_count     <='0;
            wb_addr     <='0;
        end

    end
    else begin
        last_pass       <='0;
        resp_addr_ok    <='0;
        dreq_two        <='0;
        uncached_two    <='0;
        hit_reg         <='0;
        position_reg    <='0;
        meta_two        <='0;
        state_two_reg   <='0;
        data_reg        <='0;

        meta_addr_two   <='0;
        data_raddr_two  <='0;
        data_waddr_two  <='0;
        LRU<='0;

    
        r_count     <='0;
        w_count     <='0;
        wb_addr     <='0;
    end
end


endmodule
