`include "common.svh"
`include "instr.svh"

module MMU(
    input MMU_input_t in,
    output word_t    out,

    output dbus_req_t dreq,
    input dbus_resp_t dresp,

    output logic mem_halt,
    output logic AdES, AdEL,
    output addr_t BadVAddr,
    input logic cp0_flush
);
    
    addr_t target_addr;
    logic valid;
    strobe_t strobe;
    word_t data, out_temp;
    logic[15:0] half_temp;
    logic[7:0] byte_temp;

    assign target_addr = in.base + in.offset;
    
    always_comb begin
        strobe = 4'b0000;
        data = '0;
        AdES = 0;
        AdEL = 0;
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
    
    //assign mem_halt = in.en && dreq.valid && ~dresp.data_ok;
    assign mem_halt = dreq.valid && ~dresp.data_ok;
    assign out = out_temp;
    
    always_comb begin
        out_temp = '0;
        half_temp = '0;
        byte_temp = '0;
        if(in.mem_read)begin
            unique case(in.msize)
                MSIZE4:begin
                    out_temp = dresp.data;
                end
                
                MSIZE2:begin
                    if(target_addr[1] == 1)begin
                        half_temp = dresp.data[31:16];
                    end else begin
                        half_temp = dresp.data[15:0];
                    end
                    out_temp = in.unsign_en ? `ZERO_EXTEND(half_temp, 32) : `SIGN_EXTEND(half_temp, 32);
                end
                
                MSIZE1:begin
                    unique case(target_addr[1:0])
                        2'b00:
                            byte_temp = dresp.data[7:0];
                        2'b01:
                            byte_temp = dresp.data[15:8];
                       2'b10:
                            byte_temp = dresp.data[23:16];
                       2'b11:
                            byte_temp = dresp.data[31:24];
                    endcase
                    out_temp = in.unsign_en ? `ZERO_EXTEND(byte_temp, 32) : `SIGN_EXTEND(byte_temp, 32);
                end
            endcase
        end
    end

    assign BadVAddr = AdEL | AdES ? target_addr : '0; 

endmodule