`include "common.svh"
`include "Myheadfile.svh"

module Ereg(
    input i32 E_pc, E_val1, E_val2, E_valt,
    input i6 E_icode, E_acode, E_excCode,
    input i5 E_dst, E_rt, E_rs, //for icode about REGIMM 
    input i1 E_bubble, E_stall, clk, resetn, E_inDelaySlot,
    input i32 hi_cur, lo_cur,

    output i32 e_pc, e_val3,
    output i6 e_icode, e_acode, e_excCode,
    output i5 e_dst, e_rt, e_rs,

    output i32 e_valt, hi_edata, lo_edata,
    output i1 hi_ewrite, lo_ewrite, e_inDelaySlot,
    output i1 mul_done, mul_valid, div_done, div_valid
);

    i32 e_val1, e_val2;
    i6 e_tCode;
    i1 extend;

    always_ff @(posedge clk) begin
        if(~resetn) begin
            //e_pc <= 0;
            e_acode <= 0;
            e_icode <= 0;
            e_dst <= 0;
            e_val1 <= 0;
            e_val2 <= 0;
            e_valt <= 0;
            e_rt <= 0;
            e_rs <= 0;
            e_tCode <= '0;
            e_inDelaySlot <= '0;
        end else if(E_stall) begin

        end else if(E_bubble) begin
            //e_pc <= 0;
            e_acode <= 0;
            e_icode <= 0;
            e_dst <= 0;
            e_val1 <= 0;
            e_val2 <= 0;
            e_valt <= 0;
            e_rt <= 0;
            e_rs <= 0;
            e_tCode <= '0;
            e_inDelaySlot <= '0;
        end else begin
            e_pc <= E_pc;
            e_icode <= E_icode;
            e_acode <= E_acode;
            e_dst <= E_dst;
            e_val1 <= E_val1;
            e_val2 <= E_val2;
            e_valt <= E_valt;
            e_rt <= E_rt;
            e_rs <= E_rs;
            e_tCode <= E_excCode;
            e_inDelaySlot <= E_inDelaySlot;
        end
    end
    
//overflow
    i1 cmp_sig;
    assign cmp_sig = extend ^ e_val3[31];
    i1 overflow;
    always_comb begin
        unique case (e_icode)
            ADDI: overflow = cmp_sig;
            SPE: begin
                unique case(e_acode)
                    ADD: overflow = cmp_sig;
                    SUB: overflow = cmp_sig;
                    default: overflow = '0;
                endcase
            end
            default: overflow = '0;
        endcase
    end
    assign e_excCode = e_tCode[5] ? e_tCode : (overflow ? 6'b101100:6'b000000);

//ALU
    always_comb begin
        unique case (e_icode)
            ADDI:  {extend ,e_val3} = {e_val1[31], e_val1} + {e_val2[31], e_val2};
            ADDIU: e_val3 = e_val1 + e_val2;
            ANDI:  e_val3 = e_val1 & e_val2;
            JAL:   e_val3 = e_val2;          //f_pc
            LUI:   e_val3 = e_val2;          //immeZF
            LW:    e_val3 = e_val1 + e_val2;
            ORI:   e_val3 = e_val1 | e_val2;
            SLTI:  e_val3 = ($signed(e_val1) < $signed(e_val2)) ? 32'h0000_0001 : 32'h0000_0000;
            SLTIU: e_val3 = (e_val1 < e_val2) ? 32'h0000_0001 : 32'h0000_0000;
            SW:    e_val3 = e_val1 + e_val2;
            XORI:  e_val3 = e_val1 ^ e_val2;
            SPE:begin
                unique case (e_acode)
                    XOR_:  e_val3 = e_val1 ^ e_val2;
                    SUBU:  e_val3 = e_val1 - e_val2;            
                    SRL:   e_val3 = e_val2 >> e_val1[4:0];
                    SRA:   e_val3 = $signed(e_val2) >>> e_val1[4:0];
                    SLTU:  e_val3 = (e_val1 < e_val2) ? 32'h0000_0001 : 32'h0000_0000;
                    SLT:   e_val3 = ($signed(e_val1) < $signed(e_val2)) ? 32'h0000_0001 : 32'h0000_0000;
                    SLL:   e_val3 = e_val2 << e_val1[4:0];   // the bubble selection, making sure it becomes 0.
                    OR_:   e_val3 = e_val1 | e_val2;
                    NOR_:  e_val3 = ~(e_val1 | e_val2);
                    AND_:  e_val3 = e_val1 & e_val2;
                    ADDU:  e_val3 = e_val1 + e_val2;

                    JALR:  e_val3 = e_val2;
                    SLLV:  e_val3 = e_val2 << e_val1[4:0];
                    SRAV:  e_val3 = $signed(e_val2) >>> e_val1[4:0];
                    SRLV:  e_val3 = e_val2 >> e_val1[4:0];

                    MFHI:  e_val3 = hi_cur;   //write_back
                    MFLO:  e_val3 = lo_cur;

                    ADD:   {extend, e_val3} = {e_val1[31], e_val1} + {e_val2[31], e_val2};
                    SUB:   {extend, e_val3} = {e_val1[31], e_val1} - {e_val2[31], e_val2};
                    default: e_val3 = 0;
                endcase
            end
            SPE2: begin
                unique case (e_acode)
                    MUL: {tmp0, e_val3} = (e_val1[31] ^ e_val2[31]) ? (~mulres + 1) : mulres;
                    default: e_val3 = 0;
                endcase
            end
            REGIMM: begin
                unique case (e_rt)
                    BGEZAL: e_val3 = e_val2;
                    BLTZAL: e_val3 = e_val2;
                    default: e_val3 = 0;
                endcase
            end
            
            LB:   e_val3 = e_val1 + e_val2;
            LBU:  e_val3 = e_val1 + e_val2;
            LH:   e_val3 = e_val1 + e_val2;
            LHU:  e_val3 = e_val1 + e_val2;
            SB:   e_val3 = e_val1 + e_val2;
            SH:   e_val3 = e_val1 + e_val2; 

            COP0:  e_val3 = e_val1;  //for MFC0
            default: e_val3 = 0;
        endcase        
    end

    
// mult and div 
    i64 mulres, divres;
    i32 op1, op2, tmp0;
    Mul mul(
        .valid(mul_valid), .a(op1), .b(op2),
        .done(mul_done), .c(mulres),
        .*
    );

    Div div(
        .valid(div_valid), .a(op1), .b(op2),
        .done(div_done), .c(divres),
        .*
    );


//hilo_edata decode
    always_comb begin
        unique case (e_icode)
            SPE: begin
                unique case (e_acode)
                    MULTU: begin 
                        {hi_ewrite, lo_ewrite} = '1;
                        {hi_edata, lo_edata} = mulres;
                        {op1, op2} = {e_val1, e_val2};
                        mul_valid = '1;
                    end
                    MULT: begin
                        {hi_ewrite, lo_ewrite} = '1;
                        {hi_edata, lo_edata} = (e_val1[31] ^ e_val2[31]) ? (~mulres + 1) : mulres;
                        op1 = e_val1[31] ? (~e_val1 + 1) : e_val1;
                        op2 = e_val2[31] ? (~e_val2 + 1) : e_val2;
                        mul_valid = '1;
                    end 
                    DIVU: begin 
                        {hi_ewrite, lo_ewrite} = '1;
                        {hi_edata, lo_edata} = divres;
                        {op1, op2} = {e_val1, e_val2};
                        div_valid = '1;
                    end
                    DIV: begin
                        {hi_ewrite, lo_ewrite} = '1;
                        hi_edata = e_val1[31] ? (~divres[63:32] + 1) : divres[63:32];
                        lo_edata = (e_val1[31] ^ e_val2[31]) ? (~divres[31:0] + 1) : divres[31:0];
                        op1 = e_val1[31] ? (~e_val1 + 1) : e_val1;
                        op2 = e_val2[31] ? (~e_val2 + 1) : e_val2;
                        div_valid = '1;
                    end
                    default: begin
                        {hi_ewrite, lo_ewrite} = '0;
                        {mul_valid, div_valid} = '0;
                    end
                endcase 
            end
            SPE2: begin //mul
                if(e_acode === MUL)begin
                    mul_valid = 1;
                    op1 = e_val1[31] ? (~e_val1 + 1) : e_val1;
                    op2 = e_val2[31] ? (~e_val2 + 1) : e_val2;
                end else mul_valid = 0;
            end
            default: begin
                {hi_ewrite, lo_ewrite} = '0;
                {mul_valid, div_valid} = '0;
            end
        endcase
    end
    logic _unused_ok = &{1'b0, tmp0 ,1'b0};
endmodule
