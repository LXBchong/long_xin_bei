`include "common.svh"
`include "instr.svh"

module branch_predict_v2#(
    localparam int BIT_BIT = 11,
    localparam int PHT_BIT = 10,
    localparam int BTB_BIT = 10,

    localparam int BIT_SIZE = 2 ** BIT_BIT,
    localparam int PHT_SIZE = 2 ** PHT_BIT,
    localparam int BTB_SIZE = 2 ** BTB_BIT,
    localparam int RAS_TOP_SIZE = 8,
    localparam int RAS_SIZE = 2 ** RAS_TOP_SIZE
    )(
    input logic clk, resetn         ,
    input addr_t cur_PC             ,
    input logic branch_predict_fail ,
    input addr_t recover_PC       ,
    input BRU_BP_bypass_t BRU_BP_bypass,     
    input fetch2_BP_bypass_t fetch2_BP_bypass,
    output branch_predict_t bp_info ,
    output addr_t next_PC,
    input logic eret, cp0_flush, d_flush,
    input addr_t EPC, d_flush_PC, f2_flush_PC,
    input logic no_DS, f2_flush
);
    addr_t predict_PC, next_PC_tmp;
    BIT_t[BIT_SIZE - 1 : 0] BIT, BIT_nxt;
    PHT_t[PHT_SIZE - 1 : 0] PHT, PHT_nxt;
    addr_t[BTB_SIZE - 1 : 0] BTB, BTB_nxt;
    RAS_t[RAS_SIZE - 1 : 0] RAS, RAS_nxt;
    logic jump, is_ret, branch_taken, is_second_branch;
    logic[RAS_TOP_SIZE - 1 : 0] RAS_top, RAS_top_nxt;

    logic branch_in_exec1, branch_result, check;
    word_t tag;
    addr_t branch_ins_PC, branch_jump_PC, branch_ins_PC2;

    assign branch_in_exec1 = BRU_BP_bypass.branch_in_exec;
    assign branch_result = BRU_BP_bypass.branch_result;
    assign branch_ins_PC = BRU_BP_bypass.branch_ins_PC[2] == 1 ? BRU_BP_bypass.branch_ins_PC + 32'd4 : BRU_BP_bypass.branch_ins_PC;
    assign branch_ins_PC2 = BRU_BP_bypass.branch_ins_PC; 
    assign is_second_branch = BRU_BP_bypass.branch_ins_PC[2] == 1;
    assign branch_jump_PC = BRU_BP_bypass.jump_PC;

    assign bp_info.branch_taken = branch_taken;
    assign bp_info.predict_PC = next_PC_tmp;
    assign next_PC = next_PC_tmp;

    //assign is_branch, jump
    always_comb begin
        jump = 0;
        is_ret = 0;
        for(int i = 0; i < BIT_SIZE; i++) begin
            if(i == cur_PC[13 : 14 - BIT_BIT]) begin
                is_ret = BIT[i].is_ret;
            end
        end
        for(int j = 0; j < PHT_SIZE; j++) begin
            if(j == cur_PC[13 : 14 - PHT_BIT])
                jump = PHT[j] == 2'd3 || PHT[j] == 2'd2 ? 1 : 0; 
        end
    end

    //assign predict PC
    always_comb begin
        branch_taken = 0;
        predict_PC = {cur_PC[31:3], 3'd0} + 32'd8;
        for(int k = 0; k < BTB_SIZE; k++) begin
            if(k == cur_PC[13 : 14 - BTB_BIT] && jump) begin
                branch_taken = 1;
                predict_PC = BTB[k];
            end
        end
        if(is_ret) begin
            for(int y = 0; y < RAS_SIZE; y++) begin
                if(y == RAS_top) begin
                    branch_taken = 1;
                    predict_PC = RAS[y].PC;
                end
            end
        end
    end

    //assign BIT/PHT/BTB nxt
    always_comb begin
        BIT_nxt = BIT;
        PHT_nxt = PHT;
        BTB_nxt = BTB;
        check = 0;
        tag = '0;
        if(fetch2_BP_bypass.valid) begin
            for(int r = 0; r < BIT_SIZE; r++) begin
                if(r == fetch2_BP_bypass.PC[13 : 14 - BIT_BIT]) begin
                    BIT_nxt[r].is_ret = fetch2_BP_bypass.is_ret;
                end
            end
        end
        if(branch_in_exec1) begin
            for(int e = 0; e < PHT_SIZE; e++) begin
                if(e == branch_ins_PC[13 : 14 - PHT_BIT]) begin
                    if(branch_result && PHT[e] != 2'd3) begin
                        PHT_nxt[e] = PHT[e] + 1;
                        check = 1;
                        tag = e;
                    end else if(~branch_result && PHT[e] != 2'd0)
                        PHT_nxt[e] = PHT[e] - 1;
                end
                if(e == branch_ins_PC2[13 : 14 - PHT_BIT] && is_second_branch) begin
                    if(PHT[e] != 2'd0)
                        PHT_nxt[e] = PHT[e] - 1;
                end
            end
            for(int w = 0; w < BTB_SIZE; w++) begin
                if(w == branch_ins_PC[13 : 14 - BTB_BIT]) begin
                    BTB_nxt[w] = branch_jump_PC;
                end
                if(w == branch_ins_PC2[13 : 14 - BTB_BIT] && is_second_branch) begin
                    BTB_nxt[w] = '0;
                end
            end
        end
    end

    //assign RAS nxt
    always_comb begin
        RAS_nxt = RAS;
        RAS_top_nxt = RAS_top;
        if(BRU_BP_bypass.branch_in_exec) begin
            if(BRU_BP_bypass.is_ret) begin
                for(int t = 0; t < RAS_SIZE; t++) begin
                    if(t == RAS_top) begin
                        if(RAS[t].counter == 0) begin
                            RAS_top_nxt = RAS_top - 1;
                            RAS_nxt[t] = '0;
                        end else begin
                            RAS_nxt[t].counter = RAS[t].counter - 8'd1;
                        end
                    end
                end
            end else if(BRU_BP_bypass.is_call) begin
                for(int t = 0; t < RAS_SIZE; t++) begin
                    if(t == RAS_top) begin
                        if(RAS[t].PC == BRU_BP_bypass.branch_ins_PC 
                            && RAS[t].counter != 8'hff) begin
                               RAS_nxt[t].counter = RAS[t].counter + 1;
                        end else begin
                            if(t != RAS_SIZE - 1) begin
                                RAS_top_nxt = RAS_top + 1;
                                RAS_nxt[t + 1].PC = BRU_BP_bypass.branch_ins_PC ;
                            end else begin
                                RAS_top_nxt = '0;
                                RAS_nxt[0].PC = BRU_BP_bypass.branch_ins_PC ;
                                RAS_nxt[0].counter = '0;
                            end
                        end
                    end
                end
            end
        end
    end

    always_comb begin
        next_PC_tmp = predict_PC == '0 ? {cur_PC[31:3], 3'd0} + 32'd8 : predict_PC;

        if(cp0_flush)
            next_PC_tmp = 32'hbfc00380;
        else if(eret)
            next_PC_tmp = EPC;
        else if(branch_predict_fail)
            next_PC_tmp = recover_PC;
        else if(d_flush)
            next_PC_tmp = d_flush_PC;
        else if(f2_flush)
            next_PC_tmp = f2_flush_PC;
        else if(no_DS)
            next_PC_tmp = fetch2_BP_bypass.PC + 32'd8;
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            BIT <= '0;
            for(int q = 0; q < PHT_SIZE; q++) begin
                PHT[q] <= 2'd1;
            end
            BTB <= '0;  
            RAS <= '0;
            RAS_top <= '0;
        end else begin
            BIT <= BIT_nxt;
            PHT <= PHT_nxt;
            BTB <= BTB_nxt;
            RAS <= RAS_nxt;
            RAS_top <= RAS_top_nxt;
        end
    end

endmodule