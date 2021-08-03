`include "common.svh"
`include "instr.svh"
`include "shortcut.svh"

module AGU3(
    input AGU_input_t in,
    output word_t    out,

    input dbus_resp_t dresp,
    output logic mem_halt,
    input logic exception
);
    logic[15:0] half_temp;
    logic[7:0] byte_temp;
    word_t out_temp;
    addr_t target_addr;
    
    //assign mem_halt = in.en && dreq.valid && ~dresp.data_ok;
    assign mem_halt = in.en && ~dresp.data_ok && ~exception;
    assign out = out_temp;
    
    assign target_addr = in.base + in.offset;
    
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



endmodule