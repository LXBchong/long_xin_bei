`include "common.svh"
`include "instr.svh"

module queue(
    input logic clk, resetn, flush,

    input decode_t[3:0] in,
    input logic[3:0] in_en,
    output decode_t[1:0] out,

    input logic[1:0] issued_cnt,

    output logic queue_full,
    output logic queue_empty,
    input logic fetch_halt
);
    //issue queue
    decode_t[15:0] queue, queue_nxt;
    logic[3:0] head, head_nxt, tail, tail_nxt, head_plus_one, tail_plus_one, tail_plus_two, tail_plus_three, tail_plus_four; //circular_queue
    logic[3:0] in_cnt;

    assign head_plus_one = head + 4'd1;
    assign tail_plus_one = tail + 4'd1;
    assign tail_plus_two = tail + 4'd2;
    assign tail_plus_three = tail + 4'd3;
    assign tail_plus_four = tail + 4'd4;

    //assign out
    always_comb begin
        out = '0;
        for (int i = 0; i <= 15; i ++) begin
            if(i == head) out[0] = queue[i];
            if(head_plus_one == i) out[1] = queue[i];
        end

    end
    
    assign in_cnt = in_en[0] + in_en[1] + in_en[2] + in_en[3];
    assign tail_nxt = queue_full ? tail : tail + in_cnt;
    assign head_nxt = head + {2'b00, issued_cnt};

    assign queue_full = head == tail_plus_four || head == tail_plus_one 
        || head == tail_plus_two || head == tail_plus_three ? 1 : 0; 
        
     assign queue_empty = head == tail ? 1: 0;

    //assign queue_nxt
    always_comb begin
        queue_nxt = queue;
        for (int j = 0; j <= 15; j ++) begin
            if(in_en[0] && tail == j && ~queue_full) queue_nxt[j] = in[0];
            if(in_en[1] && tail_plus_one == j && ~queue_full) queue_nxt[j] = in[1];
            if(in_en[2] && tail_plus_two == j && ~queue_full) queue_nxt[j] = in[2];
            if(in_en[3] && tail_plus_three == j && ~queue_full) queue_nxt[j] = in[3];
            
            if(issued_cnt == 2'd1 && head == j) queue_nxt[j] = '0;
            if(issued_cnt == 2'd2 && head == j) queue_nxt[j] = '0;
            if(issued_cnt == 2'd2 && head_plus_one == j) queue_nxt[j] = '0;
        end

    end

    always_ff @(posedge clk) begin
        //reset
        if(~resetn || flush) begin
            queue <= '0;
            head <= '0;
            tail <= '0;

        end else begin
            head <= head_nxt;
            tail <= tail_nxt;
            queue <= queue_nxt;

        end 
    end
    
endmodule