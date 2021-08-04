`include "common.svh"
`include "Myheadfile.svh"

module Dreg(
    (*mark_debug = "true"*)input i32 D_pc, 
    input i6 D_icode, D_acode, D_excCode,
    input i5 D_rt, D_rs, D_rd, D_sa,
    input i1 D_stall, D_bubble, clk, resetn, D_inDelaySlot, exception,

    output i32 d_pc, d_val1, d_val2, d_valt, d_jaddr,
    output i6 d_icode, d_acode, d_excCode,
    output i5 d_dst, d_src1, d_src2, d_rt, d_rs,//to splice into imme
    output i1 d_jump, d_isJumpInstr ,d_inDelaySlot,

    input i32 w_val3, m_val3, e_val3,
    input i5 w_dst, m_dst, e_dst, 
    
    input i32 pred_pc, f_pc, //JAL
    
    input i32 d_regval1, d_regval2,
    output i5 d_regidx1, d_regidx2,
    output i32 hi_ddata, lo_ddata,
    output i1 hi_dwrite, lo_dwrite,

    output i1 d_isERET,

    input i32 d_epc, cp0_val, 
    output i1 cp0_write,
    output i5 cp0_idx, 
    output i32 cp0_data2w
);
    //consider the D_stall
    i5 d_rd, d_sa;
    i6 d_tCode;
    i32 d_newval1, d_newval2;

    always_ff @(posedge clk) begin
        if(~resetn)begin
            d_icode <= '0;
            d_acode <= '0;
            d_rt <= '0;
            d_rs <= '0;
            d_rd <= '0;
            d_sa <= '0;
            d_tCode <= '0;
            d_inDelaySlot <= '0;
        end else if(D_stall)begin
            
        end else if(D_bubble)begin
            d_icode <= '0;
            d_acode <= '0;
            d_rt <= '0;
            d_rs <= '0;
            d_rd <= '0;
            d_sa <= '0;
            d_tCode <= '0;
            d_inDelaySlot <= '0;
        end else if(D_excCode[5])begin
            d_pc <= D_pc;
            d_icode <= '0;
            d_acode <= '0;
            d_rt <= '0;
            d_rs <= '0;
            d_rd <= '0;
            d_sa <= '0;
            d_tCode <= D_excCode;
            d_inDelaySlot <= D_inDelaySlot;
        end else begin
            d_pc <= D_pc;
            d_icode <= D_icode;
            d_acode <= D_acode;
            d_rt <= D_rt;
            d_rs <= D_rs;
            d_rd <= D_rd;
            d_sa <= D_sa;
            d_tCode <= D_excCode;
            d_inDelaySlot <= D_inDelaySlot;
        end
    end

//d_isERET
    assign d_isERET = d_icode === COP0 && d_acode === ERET;
//exception
    i1 invalid_instr, self_jump;
    always_comb begin
        if(d_tCode[5])begin
            d_excCode = d_tCode;
        end else if(invalid_instr)begin
            d_excCode = 6'b101010;
        end else if(self_jump)begin
            d_excCode = 6'b100000;
        end else d_excCode = 6'b000000;
    end

    assign self_jump = d_jump ? d_pc === d_jaddr:0;
    
    always_comb begin
        unique case (d_icode)
            SPE: invalid_instr = 0;
            SPE2: invalid_instr = d_acode !== MUL;
            ADDIU: invalid_instr = 0;
            ANDI: invalid_instr = 0;
            BEQ: invalid_instr = 0;
            BNE: invalid_instr = 0;
            J: invalid_instr = 0;
            JAL: invalid_instr = 0;
            LUI: invalid_instr = 0;
            LW: invalid_instr = 0;
            ORI: invalid_instr = 0;
            SLTI: invalid_instr = 0;
            SLTIU: invalid_instr = 0;
            SW: invalid_instr = 0;
            XORI: invalid_instr = 0;
            REGIMM: invalid_instr = 0;
            BGTZ: invalid_instr = 0;
            BLEZ: invalid_instr = 0;
            LB: invalid_instr = 0;
            LBU: invalid_instr = 0;
            LH: invalid_instr = 0;
            LHU: invalid_instr = 0;
            SB: invalid_instr = 0;
            SH: invalid_instr = 0;
            ADDI: invalid_instr = 0;
            COP0: invalid_instr = 0;
            default: invalid_instr = 1;
        endcase
    end

//COP0
    always_comb begin
        cp0_write = d_icode === COP0 && d_rs === MTC0;
        cp0_data2w = d_newval2;   //already forwarding
        cp0_idx = d_rd;
    end

//stall and bubble are not proper in combinatorial logic

//link to regfile
    always_comb begin
        d_regidx1 = d_rs;
        d_regidx2 = d_rt;
    end

//select the dst 
    always_comb begin
        unique case (d_icode)
            SPE: begin  //special
                if(d_acode === JR) d_dst = 0; //the zero reg
                else d_dst = d_rd;
            end
            SPE2: d_dst = d_rd;
            ADDIU: d_dst = d_rt; 
            ANDI:  d_dst = d_rt; 
            JAL:   d_dst = 5'd31;  // GPR 31
            LUI:   d_dst = d_rt;
            LW:    d_dst = d_rt;
            ORI:   d_dst = d_rt;
            SLTI:  d_dst = d_rt;
            SLTIU: d_dst = d_rt;
            XORI:  d_dst = d_rt;
            LB:    d_dst = d_rt;
            LBU:   d_dst = d_rt;
            LH:    d_dst = d_rt;
            LHU:   d_dst = d_rt;
            ADDI:  d_dst = d_rt;
            REGIMM: begin
                unique case (d_rt)
                    BGEZAL: d_dst = 5'd31;
                    BLTZAL: d_dst = 5'd31;
                    default: d_dst = 0;
                endcase
            end
            COP0: begin
                unique case (d_rs)
                    MFC0:  d_dst = d_rt;
                    default d_dst = 0;
                endcase
            end
            default: d_dst = 0;
        endcase
    end

//select the d_src1 and d_src2: simplify the key path
    always_comb begin
        d_src1 = d_rs;
        d_src2 = (d_icode === REGIMM) ? 0 : d_rt;  //REGIMM use rt as acode
    end

//forwarding at first

    always_comb begin
        if(d_src1 === 0)d_newval1 = 0;
        else if(d_src1 === e_dst)d_newval1 = e_val3;
        else if(d_src1 === m_dst)d_newval1 = m_val3;
        else if(d_src1 === w_dst)d_newval1 = w_val3;
        else d_newval1 = d_regval1;
    end

    always_comb begin
        if(d_src2 === 0)d_newval2 = 0;
        else if(d_src2 === e_dst)d_newval2 = e_val3;
        else if(d_src2 === m_dst)d_newval2 = m_val3;
        else if(d_src2 === w_dst)d_newval2 = w_val3;
        else d_newval2 = d_regval2;
    end

//produce d_val1
    always_comb begin
        unique case (d_icode)
            J:   d_val1 = 0;  //instructions that ignore d_rs
            LUI: d_val1 = 0;
            SPE: begin
                unique case (d_acode)
                    SRA: d_val1 = {{27{1'b0}},d_sa}; 
                    SRL: d_val1 = {{27{1'b0}},d_sa}; 
                    SLL: d_val1 = {{27{1'b0}},d_sa};
                    default: d_val1 = d_newval1;
                endcase
            end
            COP0: d_val1 = cp0_val;
            default: d_val1 = d_newval1;
        endcase
    end

//produce d_val2
    i16 imme;
    assign imme ={d_rd, d_sa, d_acode};

    i32 immeZE, immeSE, immeZF;
    assign immeZE = {{16{1'b0}},imme};
    assign immeSE = {{16{d_rd[4]}},imme};
    assign immeZF = {imme, 16'h0000};

    i32 instr_idxE;  
    assign instr_idxE = {d_pc[31:28],d_rs, d_rt, d_rd, d_sa, d_acode, 2'b00};
    //though not the branch itself, but they are same in most cases.
    //may occur problems;

    always_comb begin
        unique case (d_icode)
            ADDI:  d_val2 = immeSE;
            ADDIU: d_val2 = immeSE;
            ANDI:  d_val2 = immeZE;
            LUI:   d_val2 = immeZF;
            LW:    d_val2 = immeSE;  //offset
            ORI:   d_val2 = immeZE;
            SLTI:  d_val2 = immeSE;
            SLTIU: d_val2 = immeSE;
            SW:    d_val2 = immeSE;  //offset
            XORI:  d_val2 = immeZE;
            JAL:   d_val2 = pred_pc;

            SPE:begin
                unique case (d_acode)
                    JALR: d_val2 = pred_pc; 
                    default: d_val2 = d_newval2;
                endcase
            end
            SPE2: d_val2 = d_newval2;

            LB:   d_val2 = immeSE;
            LBU:  d_val2 = immeSE;
            LH:   d_val2 = immeSE;
            LHU:  d_val2 = immeSE;
            SB:   d_val2 = immeSE;
            SH:   d_val2 = immeSE;
            REGIMM:begin
                unique case (d_rt)
                    BGEZAL: d_val2 = pred_pc;
                    BLTZAL: d_val2 = pred_pc;
                    default: d_val2 = 0;
                endcase
            end
            default: d_val2 = 0;
        endcase
    end

//jump address 
    i32 immeaddr;
    assign immeaddr = {immeSE[29:0],2'b00} + f_pc;
    always_comb begin
        unique case (d_icode)
            J:     d_jaddr = instr_idxE;
            JAL:   d_jaddr = instr_idxE;
            SPE: begin 
                unique case (d_acode)
                    JR:  d_jaddr = d_newval1;
                    JALR: d_jaddr = d_newval1;
                    default : d_jaddr = immeaddr;
                endcase
            end
            JALR:  d_jaddr = d_newval1;
            COP0:  d_jaddr = d_epc;
            default: d_jaddr = immeaddr;
        endcase
    end

//jump or not
    always_comb begin
        unique case (d_icode)
            BEQ: d_jump = (d_newval1 === d_newval2) ? 1 : 0;
            BNE: d_jump = (d_newval1 !== d_newval2) ? 1 : 0;
            J:   d_jump = 1;
            JAL: d_jump = 1;
            SPE: begin
                unique case (d_acode)
                    JR:  d_jump = 1;
                    JALR: d_jump = 1;
                    default: d_jump = 0;
                endcase
            end
            REGIMM: begin  //regard rt as code way
                unique case (d_rt)
                    BGEZ:   d_jump = ($signed(d_newval1) >= $signed(0)) ? 1 : 0;
                    BGEZAL: d_jump = ($signed(d_newval1) >= $signed(0)) ? 1 : 0;
                    BLTZ:   d_jump = ($signed(d_newval1) < $signed(0)) ? 1 : 0;
                    BLTZAL: d_jump = ($signed(d_newval1) < $signed(0)) ? 1 : 0;
                    default: d_jump = 0;
                endcase
            end
            BGTZ:   d_jump = ($signed(d_newval1) > $signed(0)) ? 1 : 0;
            BLEZ:   d_jump = ($signed(d_newval1) <= $signed(0)) ? 1 : 0;
            COP0: begin
                unique case (d_acode)
                    ERET:  d_jump = 1;
                    default: d_jump = 0;
                endcase
            end
            default: d_jump = 0;
        endcase
    end

//is d_isJumpInstr;

    always_comb begin
        unique case (d_icode)
            BEQ: d_isJumpInstr = 1;
            BNE: d_isJumpInstr = 1;
            J:   d_isJumpInstr = 1;
            JAL: d_isJumpInstr = 1;
            SPE: begin
                unique case (d_acode)
                    JR:  d_isJumpInstr = 1;
                    JALR: d_isJumpInstr = 1;
                    default: d_isJumpInstr = 0;
                endcase
            end
            REGIMM: begin  //regard rt as code way
                unique case (d_rt)
                    BGEZ:   d_isJumpInstr = 1;
                    BGEZAL: d_isJumpInstr = 1;
                    BLTZ:   d_isJumpInstr = 1;
                    BLTZAL: d_isJumpInstr = 1;
                    default: d_isJumpInstr = 0;
                endcase
            end
            BGTZ:   d_isJumpInstr = 1;
            BLEZ:   d_isJumpInstr = 1;
            COP0: begin
                unique case (d_acode)
                    ERET:  d_isJumpInstr = 1;
                    default: d_isJumpInstr = 0;
                endcase
            end
            default: d_isJumpInstr = 0;
        endcase
    end

//produce d_valt for sw 
    //assign d_valt = d_newval2;
    always_comb begin
        unique case (d_icode)
            SW:   d_valt = d_newval2;
            SB:   d_valt = d_newval2;
            SH:   d_valt = d_newval2;
            default: d_valt = 0;
        endcase
    end

// forwarding for MTHI, MTLO
    always_comb begin
        unique case (d_icode)
            SPE: begin
                unique case (d_acode)
                    MTHI: {hi_ddata, hi_dwrite} = {d_val1, 1'b1};
                    MTLO: {lo_ddata, lo_dwrite} = {d_val1, 1'b1};
                    default: {hi_dwrite, lo_dwrite} = '0;
                endcase 
            end
            default: {hi_dwrite, lo_dwrite} = '0;
        endcase
    end
    
    logic _unused_ok = &{1'b0, exception, 1'b0};
endmodule
