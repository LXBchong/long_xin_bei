`include "common.svh"
`include "instr.svh"

module AGU1(
    input AGU_input_t in,
    output dbus_req_t dreq,
    output logic AdES, AdEL,
    input logic cp0_flush
);
    
    addr_t target_addr;
    logic valid;
    strobe_t strobe;
    word_t data;

    assign target_addr = in.base + in.offset;
    
    always_comb begin
        strobe = 4'b0000;
        data = '0;
        AdES = 0;
        AdEL = 0;
        valid = 0;
        if(in.mem_write) begin
            unique case(in.msize)
                MSIZE4:begin
                    if(target_addr[1:0] != '0)begin
                        valid = 0;
                        AdES = 1;

                    end else begin
                        valid = 1;
                        strobe = 4'b1111;
                        data = in.data;
                    end
                end
                
                MSIZE2:begin
                    if (target_addr[0] != 0) begin
                        valid = 0;
                        AdES = 1;
                    end else begin
                        valid = 1;
                        if(target_addr[1] == 0) begin
                            strobe = 4'b0011;
                            data = {16'd0,in.data[15:0]};
                        end else begin
                            strobe = 4'b1100;
                            data = {in.data[15:0], 16'd0};
                        end
                    end
                end
                
                MSIZE1:begin
                    valid = 1;
                    unique case(target_addr[1:0])
                        2'b00:begin
                            strobe = 4'b0001;
                            data = {24'd0, in.data[7:0]};
                        end
                        
                        2'b01:begin
                            strobe = 4'b0010;
                            data = {16'd0, in.data[7:0], 8'd0};
                        end
                        
                        2'b10:begin
                            strobe = 4'b0100;
                            data = {8'd0, in.data[7:0], 16'd0};                   
                        end
                        
                        2'b11:begin
                            strobe = 4'b1000;
                            data = {in.data[7:0], 24'd0};                 
                        end
                    endcase 
                end
            endcase
        end

        if(in.mem_read) begin
            unique case(in.msize)
                MSIZE4:begin
                    if(target_addr[1:0] != '0)begin
                        valid = 0;
                        AdEL = 1;
                    end else begin
                        valid = 1;
                    end
                end
                
                MSIZE2:begin
                    if (target_addr[0] != 0) begin
                        valid = 0;
                        AdEL = 1;
                    end else begin
                        valid = 1;
                    end
                end
                
                MSIZE1:begin
                    valid = 1;
                end
            endcase
        end
    end

    //assign dreq
    always_comb begin
        dreq = '0;
        dreq.valid = in.en && valid && ~cp0_flush;
        dreq.addr = target_addr;
        dreq.size = in.msize;
        dreq.strobe = strobe;
        dreq.data = data;
    end

    assign BadVAddr = AdEL | AdES ? target_addr : '0; 

endmodule