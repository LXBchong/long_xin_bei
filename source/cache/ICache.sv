`include "common.svh"


module ICache(
    input logic clk,resetn,i_uncached,
    input ibus_req_t cache_ireq,
    output ibus_resp_t cache_iresp,

    output cbus_req_t icreq,
    input cbus_resp_t icresp
);

logic[Dcache_offset_bits-1:0] offset_0;
assign offset_0 = '0;

ibus_req_t ireq_reg,current_ireq;

logic first;
logic [15:0] meta_strobe;
logic [63:0] data_strobe;

word_t [Dcacheline_len-1:0] r_meta,w_meta,w_meta_two,meta_two;

typedef logic [2:0] LRU_tag;
LRU_tag [Dcache_set_num-1:0] LRU;

LRU_tag new_LRU_tag;

logic [3:0] r_count;

logic [Dcache_tag_bits-1:0] tag;
logic [Dcache_offset_bits -1:0] offset;
logic [Dcache_index_bits-1:0] index;


logic just_hit,hit,new_hit,hit_reg;

logic [1:0] position,new_position,just_position,position_reg;

logic resp_ok;

logic last_pass;  // a new request go to step_two this cycle

typedef word_t[Dcacheline_len-1:0] line_t;

line_t[Dcache_way_num-1:0] w_data,r_data,data_reg,new_data,current_data;

word_t new_word;

logic [2:0] state,new_state,state_reg;

word_t[Icacheline_len-1:0] return_instr;

word_t instr_reg,new_instr;

parameter int INSTR_SIZE = 2;
predecode_rslt_t[1:0] predecode;

logic uncached_reg,uncached;

I_LUTRAM  I_meta(.clk(clk),
            .resetn(resetn),
            .addr(index),
            .strobe(meta_strobe),
            .wdata(w_meta),
            .rdata(r_meta));

I_BRAM    I_data(.clk(clk),
            .reset(~resetn),
            .write_en(data_strobe),
            .raddr(index),
            .waddr(index),
            .wdata(w_data),
            .rdata(r_data));

//control logic
assign current_ireq =  first ? cache_ireq : ireq_reg;
assign {tag,index,offset} = current_ireq;
assign uncached = first ? i_uncached : uncached_reg;


assign cache_iresp.addr_ok  = resp_ok;
assign cache_iresp.data_ok  = resp_ok;

assign cache_iresp.data     = return_instr;
assign cache_iresp.predecode = predecode;

assign current_data     = last_pass?r_data:data_reg;


assign hit = last_pass? just_hit : hit_reg;
assign position = last_pass? just_position : position_reg;
assign state = last_pass?r_meta[position][31:29] : state_reg;



always_comb begin
    predecode ='0;
    for(int j = 0; j < 2; j++) begin//predecode
        if(return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000100 || //beq
            return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000101 || //bne
            return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000110 || //blez
            return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000111 || //bgtz
            return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000010 || //j
            return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000000 && return_instr[j[INSTR_SIZE-1:0]][5:0]   == 6'b001001 || //jalr
            return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000001 && return_instr[j[INSTR_SIZE-1:0]][20:16] == 5'b00001  || //bgez
            return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000001 && return_instr[j[INSTR_SIZE-1:0]][20:16] == 5'b10001  || //bgezal
            return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000001 && return_instr[j[INSTR_SIZE-1:0]][20:16] == 5'b00000  || //bltz
            return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000001 && return_instr[j[INSTR_SIZE-1:0]][20:16] == 5'b10010     //bltzal
            ) begin //is_branch
            predecode[j[INSTR_SIZE-1:0]] = is_branch;
        end else if (return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000000 &&
                    return_instr[j[INSTR_SIZE-1:0]][25:21] == 5'b11111  &&
                    return_instr[j[INSTR_SIZE-1:0]][5:0]   == 6'b001000
                        ) begin //is_ret jr ra
            predecode[j[INSTR_SIZE-1:0]] = is_ret;
        end else if (return_instr[j[INSTR_SIZE-1:0]][31:26] == 6'b000011) begin //is_call jal
            predecode[j[INSTR_SIZE-1:0]] = is_call;
        end else begin //normal
            predecode[j[INSTR_SIZE-1:0]] = normal;
        end
    end
end



//hit or miss & LRU
always_comb begin
    just_hit = 1'b1;
    just_position = '0;
    new_LRU_tag = LRU[index];
    
    priority case(tag)
        r_meta[0][Dcache_tag_bits-1:0]:just_position = 2'b00;
        r_meta[1][Dcache_tag_bits-1:0]:just_position = 2'b01;
        r_meta[2][Dcache_tag_bits-1:0]:just_position = 2'b10;
        r_meta[3][Dcache_tag_bits-1:0]:just_position = 2'b11;
        default: begin
            just_position=2'b0;
            just_hit=1'b0;
        end
    endcase

    if(hit)begin
        unique case(just_position)
            2'b00:begin
                new_LRU_tag[2]=1'b1;
                new_LRU_tag[1]=1'b1;
            end
            2'b01:begin
                new_LRU_tag[2]=1'b1;
                new_LRU_tag[1]=1'b0;
            end
            2'b10:begin
                new_LRU_tag[2]=1'b0;
                new_LRU_tag[0]=1'b1;
            end
            2'b11:begin
                new_LRU_tag[2]=1'b0;
                new_LRU_tag[0]=1'b0;
            end
            default:new_LRU_tag=3'b0;
        endcase
    end
    else begin
        priority case(LRU[index])
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



always_comb begin

icreq.valid     = '0;
icreq.is_write  = '0;
icreq.size      = MSIZE1;
icreq.addr      = '0;
icreq.strobe    = '0;
icreq.data      = '0;
icreq.len       = MLEN1;

new_state   = `DONE;

resp_ok         ='0;

data_strobe ='0;
meta_strobe ='0;

w_data      ='0;
w_meta      = '0;


new_word        ='0;
new_position    = position;
new_data        = current_data;
new_hit         = '0;
new_instr='0;

return_instr='0;


if(cache_ireq.valid & uncached)begin
    new_state   = `DONE;
    new_data        = current_data;
    new_hit         = 1'b0;

    if(icresp.last) begin 
        resp_ok=1'b1;
        return_instr={icresp.data,instr_reg};
    end
    else if(icresp.ready)begin
        new_instr = icresp.data;
        resp_ok=1'b0;
    end

    icreq.valid     = 1'b1;
    icreq.is_write  = 1'b0;
    icreq.size      = MSIZE4;
    icreq.addr      = {current_ireq.addr[31:3],3'b0};
    icreq.strobe    = '0;
    icreq.data      = '0;
    icreq.len       = MLEN2;
end 
else if(cache_ireq.valid & ~uncached & ~first)begin
    
    if(hit) begin

    new_hit     = 1'b1;
    unique case(state)

        `INVALID:begin  
            new_state=`READING;
            //read from memory
            icreq.valid    = 1'b1;
            icreq.is_write = 1'b0;
            icreq.size     = MSIZE4;
            icreq.addr     = {current_ireq.addr[31:Dcache_offset_bits],offset_0};
            icreq.strobe   = 4'b0;
            icreq.data     = '0;
            icreq.len      = MLEN4;
            
        end
        `VALID:begin
            resp_ok=1'b1;
            w_meta[position] = {`VALID,29'b0}+tag;
            w_data= current_data;

            data_strobe = 64'hffffffffffffffff;
            meta_strobe = 16'hffff;

            return_instr= {current_data[position][offset[Dcache_offset_bits-1:2]+1], current_data[position][offset[Dcache_offset_bits-1:2]]};
        end
        `READING:begin //wait
            if(icresp.ready)begin
                new_word = icresp.data;
                new_data[position][r_count] = new_word;
            end
            else begin
                new_word='0;
                new_data=current_data;
            end

            icreq.valid    = 1'b1;
            icreq.is_write = 1'b0;
            icreq.size     = MSIZE4;
            icreq.addr     = {current_ireq.addr[31:Dcache_offset_bits],offset_0};
            icreq.strobe   = 4'b0;
            icreq.data     = '0;
            icreq.len      = MLEN4;

            if(icresp.last) new_state = `VALID;
            else new_state = `READING;

        end
        `DONE:begin
            icreq.valid    = '0;
            icreq.is_write = '0;
            icreq.size     = MSIZE1;
            icreq.addr     = '0;
            icreq.strobe   = '0;
            icreq.data     = '0;
            icreq.len      = MLEN1;
        end
        default:begin
            new_data='0;
            new_word='0;
        end
    endcase
    end
    else begin
        new_hit = 1'b1;
        new_state=`READING;
        //read from memeory
        icreq.valid    = 1'b1;
        icreq.is_write = 1'b0;
        icreq.size     = MSIZE4;
        icreq.addr     = {current_ireq.addr[31:Dcache_offset_bits],offset_0};
        icreq.strobe   = 4'b0;
        icreq.data     = '0;
        icreq.len      = MLEN4;
    end
end
else begin
    new_state   = `DONE;
    new_data        = current_data;
    new_hit         = 1'b0;

    icreq.valid     = '0;
    icreq.is_write  = '0;
    icreq.size      = MSIZE1;
    icreq.addr      = '0;
    icreq.strobe    = '0;
    icreq.data      = '0;
    icreq.len       = MLEN1;
end
end



always_ff @(posedge clk) begin
    if(resetn)begin
        if(first) begin
            last_pass<=1'b1;
            ireq_reg<=cache_ireq;
            uncached_reg<=i_uncached;
        end 
        else last_pass<=1'b0;

        if(cache_ireq.valid ) first   <=1'b0;
        if(cache_iresp.data_ok) first <=1'b1;


        if(cache_ireq.valid&first)begin
            LRU[index]    <=new_LRU_tag;
        end
        else if(cache_ireq.valid&~first)begin
            data_reg        <=new_data;
            hit_reg         <=new_hit;
            position_reg    <=new_position;
            state_reg           <=new_state;
        end

        if(icreq.valid & uncached & icresp.ready)begin
            if(~icresp.last) begin
                instr_reg<=new_instr;
            end
            else begin
                instr_reg<='0;
            end
        end
            
        if(icreq.valid && ~icreq.is_write && icresp.ready ) r_count <= r_count + 1;
        else if(icreq.valid && ~icreq.is_write) ;
        else r_count<='0;

        if(~cache_ireq.valid) begin

            last_pass <=1'b0;
            data_reg        <='0;
            hit_reg         <='0;
            position_reg    <='0;
            state_reg   <='0;

            r_count     <='0;
            instr_reg<='0;
            first <=1'b1;

            ireq_reg<='0;
            uncached_reg<='0;
        end


    end
    else begin
            LRU             <='0;

            last_pass <=1'b0;
            data_reg        <='0;
            hit_reg         <='0;
            position_reg    <='0;
            state_reg   <='0;

            r_count     <='0;
            instr_reg<='0;
            first<=1'b1;
    end
end


endmodule
