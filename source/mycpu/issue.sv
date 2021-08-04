
`include "common.svh"
`include "instr.svh"

module issue(
    input logic clk, resetn,
    input decode_t[1:0] issue_instr,
    output exec_input_t exec_input,
    output logic[1:0]   issue_cnt,
    output regid_t ra1, ra2, ra3, ra4,
    input word_t rd1_reg, rd2_reg, rd3_reg, rd4_reg,
    input logic queue_empty, mem_halt, queue_full, div_halt,
    input word_t ALU1_bypass_p2, ALU1_bypass_p3, ALU2_bypass_p2, ALU2_bypass_p3,
    input logic stall_e1, stall_e2, stall_e3, exception_flag
);
    logic first_instr_ready, second_instr_ready;
    ALU_input_t  ALU1_input, ALU2_input;
    BRU_input_t  BRU_input;
    AGU_input_t  AGU_input;
    HILO_input_t HILO_input;
    MLT_input_t MLT_input;
    DIV_input_t DIV_input;
    COP0_input_t COP0_input;
    exec_reg_t   exec_reg1, exec_reg2;

    scoreboard_t[31:0] scoreboard, scoreboard_nxt;
    scoreboard_t scoreboard_hi, scoreboard_lo, scoreboard_hi_nxt, scoreboard_lo_nxt;
    word_t rd1, rd2, rd3, rd4;
    
    //is regA and regB ready for first/second instr?
    always_comb begin
        first_instr_ready = 1;
        second_instr_ready = 1;
        for (int i = 1; i <= 31; i ++) begin
            if((scoreboard[i].pending && ((scoreboard[i].fu != ALU1 && scoreboard[i].fu != ALU2) 
                || (scoreboard[i].fu == ALU1 && scoreboard[i].phase == 1) ||  (scoreboard[i].fu == ALU2 && scoreboard[i].phase == 1))) 
                && ((issue_instr[0].read_en_A && issue_instr[0].regA == i) || (issue_instr[0].read_en_B && issue_instr[0].regB == i))
                || issue_instr[0].PC == '0
                || (issue_instr[0].read_hi && scoreboard_hi.pending)
                || (issue_instr[0].read_lo && scoreboard_lo.pending))
                first_instr_ready = 0;

            if(scoreboard[i].pending 
            && ((issue_instr[1].read_en_A && issue_instr[1].regA == i) || (issue_instr[1].read_en_B && issue_instr[1].regB == i))
            || issue_instr[1].PC == '0                
            || (issue_instr[1].read_hi && scoreboard_hi.pending)
            || (issue_instr[1].read_lo && scoreboard_lo.pending)
            || ((issue_instr[1].read_hi || issue_instr[1].read_lo) && issue_instr[0].unit == U_MLT))
                second_instr_ready = 0;
        
        end
    end
    
    //issue instrs
    always_comb begin
        issue_cnt = '0;
        ra1 = R0;
        ra2 = R0;
        ra3 = R0;
        ra4 = R0;
        exec_reg1 = '0;
        exec_reg2 = '0;

        if(~first_instr_ready || queue_empty || mem_halt || div_halt
            || (issue_instr[0].unit == U_BRANCH && (issue_instr[1].PC == '0 || ~second_instr_ready))
            || exception_flag) begin
            issue_cnt = '0;

        end else if (~second_instr_ready 
            || (issue_instr[0].unit == U_MEMORY && issue_instr[1].unit == U_MEMORY) //double mem instr
            || (issue_instr[1].unit == U_BRANCH)
            || (issue_instr[0].write_en_C && issue_instr[1].write_en_C && issue_instr[0].regC == issue_instr[1].regC)
            || (issue_instr[0].write_en_C && (issue_instr[0].regC == issue_instr[1].regA || issue_instr[0].regC == issue_instr[1].regB))
            || (issue_instr[0].unit == U_HILO && issue_instr[1].unit == U_HILO)
            || (issue_instr[0].unit == U_COP0)
            || (issue_instr[1].unit == U_MEMORY && issue_instr[0].unit != U_BRANCH))
        begin
            issue_cnt = 2'd1;
            ra1 = issue_instr[0].regA;
            ra2 = issue_instr[0].regB;
            exec_reg1.target_reg = issue_instr[0].write_en_C ? issue_instr[0].regC : R0;
            exec_reg1.en = 1;
            exec_reg1.PC = issue_instr[0].PC;
            exec_reg1.RI = issue_instr[0].RI;

            unique case(issue_instr[0].unit)
                U_BRANCH:begin 
                    exec_reg1.fu = BRU; //this should not happen
                end

                U_MEMORY:begin
                    exec_reg1.fu = AGU;
                end

                U_ALU:begin
                    exec_reg1.fu = ALU1;
                end
                
                U_HILO:begin
                    exec_reg1.fu = HILO;
                end

                U_MLT:begin
                    exec_reg1.fu = MLT;
                end

                U_DIV:begin
                    exec_reg1.fu = DIV;
                end

                U_COP0:begin
                    exec_reg1.fu = CP0;
                end

                default: exec_reg1.fu = None;
            endcase

        end else begin
            issue_cnt = 2'd2;
            ra1 = issue_instr[0].regA;
            ra2 = issue_instr[0].regB;
            ra3 = issue_instr[1].regA;
            ra4 = issue_instr[1].regB;
            exec_reg1.target_reg = issue_instr[0].write_en_C ? issue_instr[0].regC : R0;
            exec_reg2.target_reg = issue_instr[1].write_en_C ? issue_instr[1].regC : R0;
            exec_reg1.en = 1;
            exec_reg1.PC = issue_instr[0].PC;
            exec_reg2.en = 1;
            exec_reg2.PC = issue_instr[1].PC;
            exec_reg1.RI = issue_instr[0].RI;
            exec_reg2.RI = issue_instr[1].RI;

            unique case(issue_instr[0].unit)
                U_BRANCH:begin 
                    exec_reg1.fu = BRU;
                end

                U_MEMORY:begin
                    exec_reg1.fu = AGU;
                end

                U_ALU:begin
                    exec_reg1.fu = ALU1;
                end

                U_HILO:begin
                    exec_reg1.fu = HILO;
                end

                U_MLT:begin
                    exec_reg1.fu = MLT;
                end

                U_DIV:begin
                    exec_reg1.fu = DIV;
                end

                U_COP0:begin
                    exec_reg1.fu = CP0;
                end

                default: exec_reg1.fu = None;
            endcase

            unique case(issue_instr[1].unit)
                U_BRANCH:begin 
                    exec_reg2.fu = BRU;
                end

                U_MEMORY:begin
                    exec_reg2.fu = AGU;
                end

                U_ALU:begin
                    exec_reg2.fu = ALU2;
                end

                U_HILO:begin
                    exec_reg2.fu = HILO;
                end

                U_MLT:begin
                    exec_reg2.fu = MLT;
                end

                U_DIV:begin
                    exec_reg2.fu = DIV;
                end

                U_COP0:begin
                    exec_reg2.fu = CP0;
                end

                default: exec_reg2.fu = None;
            endcase

        end
    end

    //assign scoreboard_nxt
    always_comb begin
        scoreboard_nxt = scoreboard;
        
        for (int i = 1; i <= 31; i ++) begin
            if(scoreboard[i].pending == 1) begin
                if(scoreboard[i].phase == 2'd3 && ~stall_e3)
                    scoreboard_nxt[i] = '0;
                else if(scoreboard[i].phase == 2'd2 && ~stall_e2)
                    scoreboard_nxt[i].phase = 2'd3;
                else if(scoreboard[i].phase == 2'd1 && ~stall_e1)
                    scoreboard_nxt[i].phase = 2'd2;
            end
            if(i == exec_reg1.target_reg) begin
                scoreboard_nxt[i].pending = 1;
                scoreboard_nxt[i].fu = exec_reg1.fu;
                scoreboard_nxt[i].phase = 1;
            end

            if(i == exec_reg2.target_reg) begin
                scoreboard_nxt[i].pending = 1;
                scoreboard_nxt[i].fu = exec_reg2.fu;
                scoreboard_nxt[i].phase = 1;
            end
        end
    end
    
    always_comb begin
        scoreboard_hi_nxt = scoreboard_hi;
        scoreboard_lo_nxt = scoreboard_lo;
        if(exec_reg1.fu == DIV || exec_reg2.fu == DIV) begin
            scoreboard_hi_nxt.pending = 1;
            scoreboard_hi_nxt.fu = DIV;
            scoreboard_hi_nxt.phase = 1;
            scoreboard_lo_nxt.pending = 1;
            scoreboard_lo_nxt.fu = DIV;
            scoreboard_lo_nxt.phase = 1;
         end
         if(exec_reg1.fu == MLT || exec_reg2.fu == MLT) begin
            scoreboard_hi_nxt.pending = 1;
            scoreboard_hi_nxt.fu = MLT;
            scoreboard_hi_nxt.phase = 1;
            scoreboard_lo_nxt.pending = 1;
            scoreboard_lo_nxt.fu = DIV;
            scoreboard_lo_nxt.phase = 1;
         end
         if(issue_instr[0].write_hi) begin
            scoreboard_hi_nxt.pending = 1;
            scoreboard_hi_nxt.fu = HILO;
            scoreboard_hi_nxt.phase = 1;
         end
         if(issue_instr[1].write_hi) begin
            scoreboard_hi_nxt.pending = 1;
            scoreboard_hi_nxt.fu = HILO;
            scoreboard_hi_nxt.phase = 1;
         end
         if(issue_instr[0].write_lo) begin
            scoreboard_lo_nxt.pending = 1;
            scoreboard_lo_nxt.fu = HILO;
            scoreboard_lo_nxt.phase = 1;
         end
         if(issue_instr[1].write_lo) begin
            scoreboard_lo_nxt.pending = 1;
            scoreboard_lo_nxt.fu = HILO;
            scoreboard_lo_nxt.phase = 1;
         end
         
         if(scoreboard_hi.pending == 1) begin
                if(scoreboard_hi.phase == 2'd3 && ~stall_e3)
                    scoreboard_hi_nxt = '0;
                else if(scoreboard_hi.phase == 2'd2 && ~stall_e2)
                    scoreboard_hi_nxt.phase = 2'd3;
                else if(scoreboard_hi.phase == 2'd1 && ~stall_e1)
                    scoreboard_hi_nxt.phase = 2'd2;
            end
         if(scoreboard_lo.pending == 1) begin
                if(scoreboard_lo.phase == 2'd3 && ~stall_e3)
                    scoreboard_lo_nxt = '0;
                else if(scoreboard_lo.phase == 2'd2 && ~stall_e2)
                    scoreboard_lo_nxt.phase = 2'd3;
                else if(scoreboard_lo.phase == 2'd1 && ~stall_e1)
                    scoreboard_lo_nxt.phase = 2'd2;
            end
    end
    
    always_comb begin
        rd1 = rd1_reg;
        rd2 = rd2_reg;
        rd3 = rd3_reg;
        rd4 = rd4_reg;
        for(int j = 1; j <= 31; j++) begin
            if(j == ra1 && scoreboard[j].pending && scoreboard[j].fu == ALU1) begin
                unique case(scoreboard[j].phase)
                    2'd1:
                        rd1 = 0; //error
                    2'd2:
                        rd1 = ALU1_bypass_p2;
                    2'd3:
                        rd1 = ALU1_bypass_p3;
                endcase 
            end else if(j == ra1 && scoreboard[j].pending && scoreboard[j].fu == ALU2) begin
                unique case(scoreboard[j].phase)
                    2'd1:
                        rd1 = '0;
                    2'd2:
                        rd1 = ALU2_bypass_p2;
                    2'd3:
                        rd1 = ALU2_bypass_p3;
                endcase 
            end
            
            if(j == ra2 && scoreboard[j].pending && scoreboard[j].fu == ALU1) begin
                unique case(scoreboard[j].phase)
                    2'd1:
                        rd2 = '0;
                    2'd2:
                        rd2 = ALU1_bypass_p2;
                    2'd3:
                        rd2 = ALU1_bypass_p3;
                endcase 
            end else if(j == ra2 && scoreboard[j].pending && scoreboard[j].fu == ALU2) begin
                unique case(scoreboard[j].phase)
                    2'd1:
                        rd2 = '0;
                    2'd2:
                        rd2 = ALU2_bypass_p2;
                    2'd3:
                        rd2 = ALU2_bypass_p3;
                endcase 
            end
            
            if(j == ra3 && scoreboard[j].pending && scoreboard[j].fu == ALU1) begin
                unique case(scoreboard[j].phase)
                    2'd1:
                        rd3 ='0;
                    2'd2:
                        rd3 = ALU1_bypass_p2;
                    2'd3:
                        rd3 = ALU1_bypass_p3;
                endcase 
            end else if(j == ra3 && scoreboard[j].pending && scoreboard[j].fu == ALU2) begin
                unique case(scoreboard[j].phase)
                    2'd1:
                        rd3 = '0;
                    2'd2:
                        rd3 = ALU2_bypass_p2;
                    2'd3:
                        rd3 = ALU2_bypass_p3;
                endcase 
            end
            
            if(j == ra4 && scoreboard[j].pending && scoreboard[j].fu == ALU1) begin
                unique case(scoreboard[j].phase)
                    2'd1:
                        rd4 = '0;
                    2'd2:
                        rd4 = ALU1_bypass_p2;
                    2'd3:
                        rd4 = ALU1_bypass_p3;
                endcase 
            end else if(j == ra4 && scoreboard[j].pending && scoreboard[j].fu == ALU2) begin
                unique case(scoreboard[j].phase)
                    2'd1:
                        rd4 ='0;
                    2'd2:
                        rd4 = ALU2_bypass_p2;
                    2'd3:
                        rd4 = ALU2_bypass_p3;
                endcase 
            end
        end
    end

    //assign fu input
    always_comb begin
        ALU1_input = '0;
        ALU2_input = '0;
        BRU_input = '0;
        AGU_input = '0;
        DIV_input = '0;
        MLT_input = '0;
        HILO_input = '0;
        COP0_input = '0;
        
        unique case(exec_reg1.fu)
            ALU1:begin
                ALU1_input.opA = rd1;
                ALU1_input.opB = issue_instr[0].instr_type == ITYPE ? issue_instr[0].imm : rd2;
                ALU1_input.shamt = issue_instr[0].read_en_B ? rd2[4:0] : issue_instr[0].shamt;
                ALU1_input.operator = issue_instr[0].operator;
                ALU1_input.en = 1;

            end

            BRU:begin
                BRU_input.opA = rd1;
                BRU_input.opB = rd2;
                BRU_input.operator = issue_instr[0].cmp;
                BRU_input.branch_taken = issue_instr[0].first ? 
                    issue_instr[0].bp_info.branch_taken : issue_instr[1].bp_info.branch_taken;
                BRU_input.en = 1;
                BRU_input.is_ret = issue_instr[0].is_ret;
                BRU_input.is_call = issue_instr[0].is_call;
                BRU_input.link_PC = issue_instr[0].PC + 32'd8;
                BRU_input.DS_RI = issue_instr[1].RI ? 1: 0;
                BRU_input.predict_PC = issue_instr[0].first ?
                    issue_instr[0].bp_info.predict_PC : issue_instr[1].bp_info.predict_PC;
                if(issue_instr[0].instr_type == INDEX) begin
                    BRU_input.jump_PC = issue_instr[0].imm;
                end else if(issue_instr[0].instr_type == RTYPE) begin
                    BRU_input.jump_PC = rd1;
                end else begin
                    BRU_input.jump_PC = issue_instr[0].jump_PC;
                end
            
            end

            AGU:begin
                AGU_input.base = rd1;
                AGU_input.offset = issue_instr[0].imm[15] ? {16'hffff, issue_instr[0].imm[15:0]} : {16'h0000, issue_instr[0].imm[15:0]};
                AGU_input.en = 1;
                AGU_input.mem_read = issue_instr[0].mem_read;
                AGU_input.mem_write = issue_instr[0].mem_write;
                AGU_input.unsign_en = issue_instr[0].unsign_en;
                AGU_input.msize = issue_instr[0].msize;
                AGU_input.data = rd2;

            end

            HILO:begin
                HILO_input.en = 1;
                HILO_input.write_hi = issue_instr[1].unit == U_MLT ? 0 : issue_instr[0].write_hi; //if so, it;s pointless to write hi/lo
                HILO_input.write_lo = issue_instr[1].unit == U_MLT ? 0 : issue_instr[0].write_lo;
                HILO_input.read_hi = issue_instr[0].read_hi;
                HILO_input.read_lo = issue_instr[0].read_lo;
                HILO_input.data = rd1;

            end

            MLT:begin
                MLT_input.en = 1;
                if(issue_instr[0].hilo_unsign == 1)begin
                    MLT_input.opA = rd1;
                    MLT_input.opB = rd2;
                    MLT_input.signed_en = 0;
                end else begin
                    MLT_input.opA = rd1[31] ? ~rd1 + 32'd1  : rd1;
                    MLT_input.opB = rd2[31] ? ~rd2 + 32'd1  : rd2;
                    MLT_input.signed_en = rd1[31] ^ rd2[31];
                end
            end

            DIV:begin
                DIV_input.en = 1;
                if(issue_instr[0].hilo_unsign == 1)begin
                    DIV_input.opA = rd1;
                    DIV_input.opB = rd2;
                    DIV_input.signed_a_en = 0;
                    DIV_input.signed_b_en = 0;
                end else begin
                    DIV_input.opA = rd1[31] ? ~rd1 + 32'd1  : rd1;
                    DIV_input.opB = rd2[31] ? ~rd2 + 32'd1  : rd2;
                    DIV_input.signed_a_en = rd1[31];
                    DIV_input.signed_b_en = rd2[31];
                end
            end

            CP0:begin
                COP0_input.en = 1;
                COP0_input.PC = issue_instr[0].PC;
                COP0_input.mf = issue_instr[0].mf;
                COP0_input.mt = issue_instr[0].mt;
                COP0_input.write_data = issue_instr[0].mt ? rd1 : 0;
                COP0_input.regsel = issue_instr[0].regsel;
                COP0_input.eret = issue_instr[0].eret;
                COP0_input.first = 1;
            end

            default:begin
            end
        endcase 

        unique case(exec_reg2.fu)
            ALU2:begin
                ALU2_input.opA = rd3;
                ALU2_input.opB = issue_instr[1].instr_type == ITYPE ? issue_instr[1].imm : rd4;
                ALU2_input.shamt = issue_instr[1].read_en_B ? rd4[4:0] : issue_instr[1].shamt;
                ALU2_input.operator = issue_instr[1].operator;
                ALU2_input.en = 1;

            end

            AGU:begin
                AGU_input.base = rd3;
                AGU_input.offset = issue_instr[1].imm[15] ? {16'hffff, issue_instr[1].imm[15:0]} : {16'h0000, issue_instr[1].imm[15:0]};
                AGU_input.en = 1;
                AGU_input.mem_read = issue_instr[1].mem_read;
                AGU_input.mem_write = issue_instr[1].mem_write;
                AGU_input.unsign_en = issue_instr[1].unsign_en;
                AGU_input.msize = issue_instr[1].msize;
                AGU_input.data = rd4;

            end

            HILO:begin
                HILO_input.en = 1;
                HILO_input.write_hi = issue_instr[1].write_hi;
                HILO_input.write_lo = issue_instr[1].write_lo;
                HILO_input.read_hi = issue_instr[1].read_hi;
                HILO_input.read_lo = issue_instr[1].read_lo;
                HILO_input.data = rd3;

            end

            MLT:begin
                MLT_input.en = 1;
                if(issue_instr[1].hilo_unsign == 1)begin
                    MLT_input.opA = rd3;
                    MLT_input.opB = rd4;
                    MLT_input.signed_en = 0;
                end else begin
                    MLT_input.opA = rd3[31] ? ~rd3 + 32'd1  : rd3;
                    MLT_input.opB = rd4[31] ? ~rd4 + 32'd1  : rd4;
                    MLT_input.signed_en = rd3[31] ^ rd4[31];
                end
            end

            DIV:begin
                DIV_input.en = 1;
                if(issue_instr[1].hilo_unsign == 1)begin
                    DIV_input.opA = rd3;
                    DIV_input.opB = rd4;
                    DIV_input.signed_a_en = 0;
                    DIV_input.signed_b_en = 0;
                end else begin
                    DIV_input.opA = rd3[31] ? ~rd3 + 32'd1  : rd3;
                    DIV_input.opB = rd4[31] ? ~rd4 + 32'd1  : rd4;
                    DIV_input.signed_a_en = rd3[31];
                    DIV_input.signed_b_en = rd4[31];
                end
            end

            CP0:begin
                COP0_input.en = 1;
                COP0_input.PC = issue_instr[1].PC;
                COP0_input.mf = issue_instr[1].mf;
                COP0_input.mt = issue_instr[1].mt;
                COP0_input.write_data = issue_instr[1].mt ? rd3 : 0;
                COP0_input.regsel = issue_instr[1].regsel;
                COP0_input.eret = issue_instr[1].eret;
                COP0_input.second = 1;
            end

            default:begin
            end
        endcase 
    end

    assign exec_input.ALU1_input = ALU1_input;
    assign exec_input.ALU2_input = ALU2_input;
    assign exec_input.BRU_input = BRU_input;
    assign exec_input.AGU_input = AGU_input;
    assign exec_input.MLT_input = MLT_input;
    assign exec_input.DIV_input = DIV_input;
    assign exec_input.HILO_input = HILO_input;
    assign exec_input.COP0_input = COP0_input;
    assign exec_input.exec_reg1 = exec_reg1;
    assign exec_input.exec_reg2 = exec_reg2;
 

    always_ff @(posedge clk) begin
        if(~resetn) begin
            scoreboard <= '0;
            scoreboard_hi <= '0;
            scoreboard_lo <= '0;
        //end else if(mem_halt || div_halt) begin
            //do nothing
        end else begin
            scoreboard <= scoreboard_nxt;
            scoreboard_hi <= scoreboard_hi_nxt;
            scoreboard_lo <= scoreboard_lo_nxt;
        end
    end

endmodule