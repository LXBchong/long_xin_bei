`include "common.svh"
`include "instr.svh"

module issue(
    logic clk, resetn,
    input decode_t[1:0] issue_instr,
    output ALU_input_t  ALU1_input, ALU2_input,
    output BRU_input_t  BRU_input,
    output MMU_input_t  MMU_input,
    output HILO_input_t HILO_input,
    output MLT_input_t MLT_input,
    output DIV_input_t DIV_input,
    output COP0_input_t COP0_input,
    output exec_reg_t   exec_reg1, exec_reg2,
    output logic[1:0]   issue_cnt,
    output regid_t ra1, ra2, ra3, ra4,
    input word_t rd1, rd2, rd3, rd4,
    input logic queue_empty, fetch_halt, mem_halt, queue_full, mlt_halt, div_halt
);
    logic first_instr_ready, second_instr_ready;

    scoreboard_t[31:0] scoreboard, scoreboard_nxt;
    
    //is regA and regB ready for first/second instr?
    always_comb begin
        first_instr_ready = 1;
        second_instr_ready = 1;
        for (int i = 1; i <= 31; i ++) begin
            if(scoreboard[i].pending 
                && ((issue_instr[0].read_en_A && issue_instr[0].regA == i) || (issue_instr[0].read_en_B && issue_instr[0].regB == i))
                || issue_instr[0].PC == '0)
                first_instr_ready = 0;

            if(scoreboard[i].pending 
            && ((issue_instr[1].read_en_A && issue_instr[1].regA == i) || (issue_instr[1].read_en_B && issue_instr[1].regB == i))
            || issue_instr[1].PC == '0)
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

        if(~first_instr_ready || queue_empty || mem_halt || mlt_halt || div_halt
            || (issue_instr[0].unit == U_BRANCH && (issue_instr[1].PC == '0 || ~second_instr_ready))) begin
            issue_cnt = '0;

        end else if (~second_instr_ready 
            || (issue_instr[0].unit == U_MEMORY && issue_instr[1].unit == U_MEMORY) //double mem instr
            || (issue_instr[1].unit == U_BRANCH)
            || (issue_instr[0].write_en_C && issue_instr[1].write_en_C && issue_instr[0].regC == issue_instr[1].regC)
            || (issue_instr[0].write_en_C && (issue_instr[0].regC == issue_instr[1].regA || issue_instr[0].regC == issue_instr[1].regB))
            || (issue_instr[0].unit == U_HILO && issue_instr[1].unit == U_HILO)
            || (issue_instr[0].unit == U_COP0 && issue_instr[1].unit == U_COP0)
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
                    exec_reg1.fu = MMU;
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
                    exec_reg1.fu = MMU;
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
                    exec_reg2.fu = MMU;
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
        scoreboard_nxt = '0;
        for (int i = 1; i <= 31; i ++) begin
            if(i == exec_reg1.target_reg) begin
                scoreboard_nxt[i].pending = 1;
                scoreboard_nxt[i].fu = exec_reg1.fu;
            end

            if(i == exec_reg2.target_reg) begin
                scoreboard_nxt[i].pending = 1;
                scoreboard_nxt[i].fu = exec_reg2.fu;
            end
        end
    end

    //assign fu input
    always_comb begin
        ALU1_input = '0;
        ALU2_input = '0;
        BRU_input = '0;
        MMU_input = '0;
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
                BRU_input.branch_taken = 0;
                BRU_input.en = 1;
                BRU_input.link_PC = issue_instr[0].PC + 32'd8;
                BRU_input.DS_RI = issue_instr[1].RI ? 1: 0;
                if(issue_instr[0].instr_type == INDEX) begin
                    BRU_input.jump_PC = issue_instr[0].imm;
                end else if(issue_instr[0].instr_type == RTYPE) begin
                    BRU_input.jump_PC = rd1;
                end else begin
                    BRU_input.jump_PC = issue_instr[0].PC + issue_instr[0].offset + 32'd4;
                end
            
            end

            MMU:begin
                MMU_input.base = rd1;
                MMU_input.offset = issue_instr[0].imm[15] ? {16'hffff, issue_instr[0].imm[15:0]} : {16'h0000, issue_instr[0].imm[15:0]};
                MMU_input.en = 1;
                MMU_input.mem_read = issue_instr[0].mem_read;
                MMU_input.mem_write = issue_instr[0].mem_write;
                MMU_input.unsign_en = issue_instr[0].unsign_en;
                MMU_input.msize = issue_instr[0].msize;
                MMU_input.data = rd2;

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

            MMU:begin
                MMU_input.base = rd3;
                MMU_input.offset = issue_instr[1].imm[15] ? {16'hffff, issue_instr[1].imm[15:0]} : {16'h0000, issue_instr[1].imm[15:0]};
                MMU_input.en = 1;
                MMU_input.mem_read = issue_instr[1].mem_read;
                MMU_input.mem_write = issue_instr[1].mem_write;
                MMU_input.unsign_en = issue_instr[1].unsign_en;
                MMU_input.msize = issue_instr[1].msize;
                MMU_input.data = rd4;

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

    always_ff @(posedge clk) begin
        if(~resetn) begin
            scoreboard <= '0;
        end else if(mem_halt || mlt_halt || div_halt) begin
            //do nothing
        end else begin
            scoreboard <= scoreboard_nxt;
        end
    end

endmodule