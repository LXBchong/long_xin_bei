`include "def.svh"

`define INVALID 3'b000
`define VALID   3'b001
`define DIRTY   3'b010
`define READING 3'b011
`define WRITING 3'b100

module Dache(
    input logic clk,resetn,d_uncached,
    input dbus_req_t cache_dreq,
    output dbus_resp_t cache_dresp

    output cbus_req_t dcreq,
    input cbus_resp_t dcresp
);

logic [3:0] meta_addr,meta_strobe;
word_t r_meta,w_meta;

typedef logic [2:0] LRU_tag;
LRU_tag [Dcache_set_num-1:0] LRU;


logic [Dcache_tag_bits-1:0] tag,tag_two;
logic [Dcache_offset_len -1:0] offset,offset_two;
logic [Dcache_set_len-1:0] index,index_two;

logic hit_one,hit_two;
logic [Dcache_set_len-1:0] position_one;

logic [15:0] data_strobe;

LUTRAM D_meta(.clk(clk),
            .addr(meta_addr),
            .strobe(meta_strobe),
            .wdata(w_meta),
            .rdata(r_meta));

BRAM D_data(.clk(clk),
            .reset(~resetn),
            .write_en(data_strobe),
            .raddr(data_raddr),
            .waddr(data_waddr),
            .wdata(w_data),
            .rdata(r_data));

//step one
assign {tag,index,offset} = cache_dreq.addr;
assign {tag_two,index_two,offset_two} = dreq_two.addr;

always_comb begin
    meta_addr = '0;
    hit_one = '0;
    position_one = '0;
    for(int i=0;i<4;i++)begin
        meta_addr  = {index,2'b00}+i;
        data_raddr = {index,2'b00}+i;

        if( tag == r_meta[Dcache_tag_bits-1:0] ) begin 
            hit_one=1'b1;
            position_one = i;
            break;
        end
    end

    if(~hit_one) begin
        priority case(LRU[index])
            3'b000: position_one = 2'b00;
            3'b001: position_one = 2'b00;
            3'b010: position_one = 2'b01;
            3'b011: position_one = 2'b01;
            3'b100: position_one = 2'b10;
            3'b101: position_one = 2'b11;
            3'b110: position_one = 2'b10;
            3'b111: position_one = 2'b11;
        endcase
    end
end



//step two

always_comb begin
if(dreq_two.valid & ~uncached_two)begin
    if(hit_two) begin
    dcreq.valid    = '0;
    dcreq.is_write = '0;
    dcreq.size     = MSIZE1;
    dcreq.addr     = '0;
    dcreq.strobe   = '0;
    dcreq.data     = '0;
    dcreq.len      = MLEN1;
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
            dcreq.len      = MLEN16;
            
        end
        VALID:begin
            step_two_ok=1'b1;
            if(dreq_two.is_write)begin
                new_state_two = DIRTY;
                unique case(offset_two[3:2])
                    2'b00:begin
                        wdata={data_two[127:32],dreq_two.data};
                        data_strobe = {12'hfff,dreq_two.strobe};
                    end
                    2'b01:begin
                        wdata={data_two[127:64],dreq_two.data,data_two[31:0]};
                        data_strobe = {8'hff,dreq_two.strobe,4'hf};
                    end
                    2'b10:begin
                        wdata={data_two[127:96],dreq_two.data,data_two[63:0]};
                        data_strobe = {4'hf,dreq_two.strobe,8'hff};
                    end
                    2'b11:begin
                        wdata={dreq_two.data,data_two[95:0]};
                        data_strobe = {dreq_two.strobe,12'hfff};
                    end
                    default:begin
                        wdata='0;
                        data_strobe = '0;
                    end
                endcase
            end
        end
    endcase
    end
end
else if(dreq_two.valid & uncached_two)begin
    
end
else begin
    
end
end

//step three


logic[127:0] data_reg,new_data,current_data;

assign current_data = last_pass?r_data:data_reg;


always_ff @(posedge clk) begin
    data_reg<=new_data;
    if(resetn) begin
        
    end
    else begin
        
    end
end


logic last_pass;  // a new request go to step_two this cycle

always_ff @(posedge clk) begin
    if(resetn)begin
        if(~stall_one) begin
            last_pass<=1'b1;

            cache_dresp.addr_ok<=1'b1;
            dreq_two<=cache_dreq;
            uncached_two<=d_uncached;
            hit_two<=hit_one;
            meta_two<=r_meta;
            state_two<=r_meta[31:29];
        end
        else last_pass<=1'b0;

        if(~stall_two) begin
            
            data_three<=data_two;
        end
    end
    else begin
        LRU<='0;
    end
end


endmodule
