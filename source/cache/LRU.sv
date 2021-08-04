`include "common.svh"
`include "instr.svh"

module LRU(
    input logic resetn,
    input logic not_funct_en,

    input LRU_func_t func,
    input index_t index,

    input position_t hit_pos,
    
    output position_t LRU_pos
);

    parameter int ASSOCIATIVITY = 1 << `ICache_position_bit;
    parameter int LRU_BIT = ASSOCIATIVITY - 1;
    parameter int LRU_ROW = 1 << `ICache_index_bit;

    parameter logic[31:0] zero_line = 32'b0;
    parameter logic[31:0] mask_line = 32'hffff_ffff;

    typedef logic[LRU_BIT-1:0] LRUline_t;
    typedef LRUline_t[LRU_ROW-1:0] LRUboard_t;

    LRUboard_t LRUboard;
    position_t modify_code;


    always_comb begin
        if (resetn) begin
            if (not_funct_en == 0) begin
                if (func == MODIFY) begin //MODIFY
                    //modify_code = mask_line[`ICache_position_bit-1:0] ^ hit_pos;
                    modify_code = ~hit_pos;
                    //4-way 2level 3bit
                    LRUboard[index][0] = modify_code[0];
                    if(modify_code[0] == 0)begin //0x
                        LRUboard[index][2] = modify_code[1];
                    end else begin//1x
                        LRUboard[index][1] = modify_code[1];
                    end
    
    /*
                    //8-way 3level 7bit
                    LRUboard[index][0] = modify_code[0];
                    if(modify_code[0] == 0)begin //0xx
                        LRUboard[index][2] = modify_code[1];
                        if(modify_code[1] == 0)begin //00x
                            LRUboard[index][6] = modify_code[2];
                        end else begin //01x
                            LRUboard[index][5] = modify_code[2];
                        end
                    end else begin//1xx
                        LRUboard[index][1] = modify_code[1];
                        if(modify_code[1] == 0)begin //10x
                            LRUboard[index][4] = modify_code[2];
                        end else begin //11x
                            LRUboard[index][3] = modify_code[2];
                        end
                    end
    */
                end else begin //REPLACE
                    for(int i = 0; i < `ICache_position_bit; i++) begin
                        LRU_pos[i] = LRUboard[index][i];
                        modify_code = ~LRU_pos;
    
                        //4-way 2level 3bit
                        LRUboard[index][0] = modify_code[0];
                        if(modify_code[0] == 0)begin //0x
                            LRUboard[index][2] = modify_code[1];
                        end else begin//1x
                            LRUboard[index][1] = modify_code[1];
                        end
    
    /*
                        //8-way 3level 7bit
                        LRUboard[index][0] = modify_code[0];
                        if(modify_code[0] == 0)begin //0xx
                            LRUboard[index][2] = modify_code[1];
                            if(modify_code[1] == 0)begin //00x
                                LRUboard[index][6] = modify_code[2];
                            end else begin //01x
                                LRUboard[index][5] = modify_code[2];
                            end
                        end else begin//1xx
                            LRUboard[index][1] = modify_code[1];
                            if(modify_code[1] == 0)begin //10x
                                LRUboard[index][4] = modify_code[2];
                            end else begin //11x
                                LRUboard[index][3] = modify_code[2];
                            end
                        end
    */
                    end
    
                end
            end else begin
                //nothing to do when register.state == MISS && miss_to_hit_flag == 0
            end
            
        end
        else begin
            for(int i = 0; i < LRU_ROW; i++) begin
                LRUboard[i] = zero_line[LRU_BIT-1:0];
                modify_code = '0;
            end
        end
        
    end

    
endmodule