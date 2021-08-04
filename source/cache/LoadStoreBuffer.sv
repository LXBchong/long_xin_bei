`include "common.svh"

module LoadStoreBuffer#(
    localparam int BUFFER_LEN = 8
)(
    input clk,resetn,
    input tbus_req_t dtreq,
    input cbus_resp_t dcresp,

    output tbus_resp_t dtresp,
    output cbus_req_t dcreq
);


tbus_req_t[BUFFER_LEN-1:0] req_buffer;
tbus_req_t fill_req;

logic[3:0] pointer,position;
logic buffer_free,data_ok;

logic hit,push,empty;

logic[2:0] state,new_state;

logic[3:0] w_count,r_count;

word_t[Dcacheline_len-1:0] buffer_data,new_data,data_reg;
word_t new_word;


assign buffer_free = pointer >= BUFFER_LEN[3:0] ? 1'b0:1'b1;
assign empty = pointer == 0 ? 1'b1 : 1'b0;

assign fill_req = '0;

assign dtresp.data_ok   = data_ok;
assign dtresp.data      = buffer_data;




always_comb begin
    hit         = '0;
    position    = '0;
    push        = '0;

    dcreq.valid     = 1'b0;
    dcreq.is_write  = 1'b0;
    dcreq.size      = MSIZE1;
    dcreq.addr      = '0;
    dcreq.strobe    = '0;
    dcreq.data      = '0;
    dcreq.len       = MLEN1;

    data_ok         = 1'b0;
    buffer_data     = '0;

    new_state       = `INVALID;
    new_data        = data_reg;
    new_word        = '0;

    if(state == `READING) begin
        if(dcresp.ready)begin
            new_word = dcresp.data;
            new_data[r_count] = new_word;
        end
        else begin
            new_word='0;
            new_data=data_reg;
        end

        dcreq.valid    = 1'b1;
        dcreq.is_write = 1'b0;
        dcreq.size     = MSIZE4;
        dcreq.addr     = dtreq.addr;
        dcreq.strobe   = 4'b0;
        dcreq.data     = '0;
        dcreq.len      = MLEN4;

        if(dcresp.last) begin
            data_ok=1'b1;
            new_state = `INVALID;
            buffer_data = new_data;
        end 
        else new_state = `READING;

    end

    else begin
    if(dtreq.valid & dtreq.is_uncached && state!=`WRITING)begin
        if(dcresp.last) begin
            data_ok = 1'b1;
            buffer_data[0] = dcresp.data;
        end 

        dcreq.valid     = 1'b1;
        dcreq.is_write  = dtreq.is_write;
        dcreq.size      = dtreq.size;
        dcreq.addr      = dtreq.addr;
        dcreq.strobe    = dtreq.strobe;
        dcreq.data      = dtreq.data[0];
        dcreq.len       = MLEN1;

        
    end
    else if(dtreq.valid & ~dtreq.is_uncached )begin
        for(int i = 0;i<BUFFER_LEN;i++) begin
            if(req_buffer[i].addr==dtreq.addr) begin
                position = i[3:0];
                hit=1'b1;
                break;
            end 
        end

        if(hit)begin
            data_ok =1'b1;
            if(~dtreq.is_write) buffer_data = req_buffer[position].data;
        end
        else begin
            if(buffer_free & dtreq.is_write) begin
                push        = 1'b1;
                data_ok     = 1'b1;
                buffer_data = '0;
            end
            else if(~dtreq.is_write && state!=`WRITING)begin
                dcreq.valid     = 1'b1;
                dcreq.is_write  = 1'b0;
                dcreq.size      = MSIZE4;
                dcreq.addr      = dtreq.addr;
                dcreq.strobe    = 4'b0;
                dcreq.data      = '0;
                dcreq.len       = MLEN4;

                new_state       = `READING;
            end
        end
    end
    else if(~dtreq.valid & ~empty && state!=`WRITING)begin
        dcreq.valid     = 1'b1;
        dcreq.is_write  = 1'b1;
        dcreq.size      = MSIZE4;
        dcreq.addr      = dtreq.addr;
        dcreq.strobe    = 4'b1111;
        dcreq.data      = req_buffer[0].data[w_count];
        dcreq.len       = MLEN4;

        new_state       = `WRITING;
    end
    end
    if(state == `WRITING) begin
        dcreq.valid    = 1'b1;
        dcreq.is_write = 1'b1;
        dcreq.size     = MSIZE4;
        dcreq.addr     = req_buffer[0].addr;
        dcreq.strobe   = 4'b1111;
        dcreq.data     = req_buffer[0].data[w_count];
        dcreq.len      = MLEN4;

        if(dcresp.last) begin
            new_state = `INVALID;
            buffer_data='0;
        end 
        else new_state = `WRITING;
    end
end


always_ff@(posedge clk)begin
    if(resetn)begin
        

        if(state == `WRITING && dcresp.last) begin
            pointer<=pointer-1;
            req_buffer <= {fill_req,req_buffer[BUFFER_LEN-1:1]};
        end 

        state       <= new_state;
        data_reg    <= new_data;

        if(hit & dtreq.is_write) req_buffer[position] <= dtreq;

        if(push) begin
            req_buffer[pointer] <= dtreq;
            pointer             <= pointer + 1;
        end 

        if(dcreq.valid && ~dcreq.is_write && dcresp.ready ) r_count <= r_count + 1;
        else if(dcreq.valid && ~dcreq.is_write) ;
        else r_count<='0;

        if(dcreq.valid && dcreq.is_write && dcresp.ready ) w_count <= w_count + 1;
        else if(dcreq.valid && dcreq.is_write) ;
        else w_count<='0;
    end
    else begin
        pointer     <='0;
        req_buffer  <='0;
        state       <='0;
        data_reg    <='0;
        r_count     <='0;
        w_count     <='0;
    end
end
    
endmodule