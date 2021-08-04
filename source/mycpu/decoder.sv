`include "common.svh"
`include "instr.svh"
`include "shortcut.svh"

module decoder (
    input decoder_input_t decode_input,
    input branch_buffer_t branch_buffer,
    input branch_predict_t bp_info,
    output decode_t decode_info,
    output branch_predict_t bp_info_out,
    output logic d_flush,
    output addr_t flush_PC
);
    logic[15:0] imm;
    logic[17:0] branch_imm;
    opcode_t opcode;
    addr_t PC;
    instr_t instr;

    assign PC = decode_input.PC;
    assign instr = decode_input.instr;
    assign imm = instr.payload.itype.imm;
    assign branch_imm = {instr.payload.itype.imm, 2'b00};
    assign opcode = instr.opcode;
    //big always_comb for decoding instrs

    //TODO calculate branchPC to check whether predictPC is right
    always_comb begin
        decode_info = '0;
        decode_info.PC = PC;
        decode_info.bp_info = bp_info;

        unique case(opcode)
            OP_ADDI:begin
                decode_info.unit = U_ALU;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.operator = AR_ADD;
            end

            OP_ADDIU:begin
                decode_info.unit = U_ALU;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.operator = AR_ADDU;

            end

            OP_ANDI:begin
                decode_info.unit = U_ALU;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = `ZERO_EXTEND(imm, 32);

                decode_info.operator = AR_AND;

            end

            OP_BEQ:begin
                decode_info.unit = U_BRANCH;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = instr.payload.itype.rt;
                decode_info.regC = R0;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b1;
                decode_info.write_en_C = 1'b0;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.cmp = CMP_EQL;
                decode_info.jump_PC = PC + `SIGN_EXTEND(branch_imm, 32) + 32'd4;

            end
            
            OP_BGTZ:begin
                decode_info.unit = U_BRANCH;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = R0;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b1;
                decode_info.write_en_C = 1'b0;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.cmp = CMP_G;
                decode_info.jump_PC = PC + `SIGN_EXTEND(branch_imm, 32) + 32'd4;

            end

            OP_BLEZ:begin
                decode_info.unit = U_BRANCH;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = R0;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b0;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.cmp = CMP_LE;
                decode_info.jump_PC = PC + `SIGN_EXTEND(branch_imm, 32) + 32'd4;


            end

            OP_BNE:begin
                decode_info.unit = U_BRANCH;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = instr.payload.itype.rt;
                decode_info.regC = R0;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b1;
                decode_info.write_en_C = 1'b0;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.cmp = CMP_NE;
                decode_info.jump_PC = PC + `SIGN_EXTEND(branch_imm, 32) + 32'd4;

            end

            OP_BTYPE:begin
                decode_info.unit = U_BRANCH;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = R0;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b1;
                decode_info.write_en_C = 1'b0;
                decode_info.imm = `SIGN_EXTEND(imm, 32);
               
                decode_info.jump_PC = PC + `SIGN_EXTEND(branch_imm, 32) + 32'd4;

                unique case(instr.payload.itype.rt)
                    BR_BLTZ:
                        decode_info.cmp = CMP_L;

                    BR_BGEZ:
                        decode_info.cmp = CMP_GE;

                    BR_BLTZAL:begin
                        decode_info.regC = RA;
                        decode_info.write_en_C = 1'b1;
                        decode_info.cmp = CMP_L;
                    end

                    BR_BGEZAL:begin
                        decode_info.regC = RA;
                        decode_info.write_en_C = 1'b1;
                        decode_info.cmp = CMP_GE;
                    end
                    
                    default: begin
                         decode_info = '0;
                         decode_info.PC = PC;
                         decode_info.RI = 1;
                    end
                    
                endcase
            end

            OP_COP0:begin
                if(instr.payload.cop0_co.co == 0) begin
                    unique case(instr.payload.cop0.funct)
                        CFN_MF:begin
                            decode_info.unit = U_COP0;
                            decode_info.instr_type = COP0;

                            decode_info.regA = R0;
                            decode_info.regB = R0;
                            decode_info.regC = instr.payload.cop0.rt;

                            decode_info.read_en_A = 1'b0;
                            decode_info.read_en_B = 1'b0;
                            decode_info.write_en_C = 1'b1;

                            decode_info.regsel = {instr.payload.cop0.rd, instr.payload.cop0.sel};
                            decode_info.mf = 1;
                        end

                        CFN_MT:begin
                            decode_info.unit = U_COP0;
                            decode_info.instr_type = COP0;

                            decode_info.regA = instr.payload.cop0.rt;;
                            decode_info.regB = R0;
                            decode_info.regC = R0;

                            decode_info.read_en_A = 1'b1;
                            decode_info.read_en_B = 1'b0;
                            decode_info.write_en_C = 1'b0;
                            
                            decode_info.regsel = {instr.payload.cop0.rd, instr.payload.cop0.sel};
                            decode_info.mt = 1;
                        end
                        
                        default: begin
                            decode_info = '0;
                            decode_info.PC = PC;
                            decode_info.RI = 1;
                        end
                        
                    endcase
                end else begin //ERET
                    decode_info.unit = U_COP0;
                    decode_info.instr_type = COP0;

                    decode_info.eret = 1;
                end
            end 

            OP_J:begin
                decode_info.unit = U_BRANCH;
                decode_info.instr_type = INDEX;

                decode_info.imm = {PC[31:28], instr.payload.index, 2'b00};

                decode_info.cmp = CMP_J;

            end
            
            OP_JAL:begin
                decode_info.unit = U_BRANCH;
                decode_info.instr_type = INDEX;

                decode_info.regC = RA;
                decode_info.write_en_C = 1'b1;

                decode_info.imm = {PC[31:28], instr.payload.index, 2'b00};

                decode_info.cmp = CMP_J;

            end

            OP_LB:begin
                decode_info.unit = U_MEMORY;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = {16'd0, instr.payload.itype.imm};

                decode_info.mem_read = 1'b1;
                decode_info.mem_write = 1'b0;
                decode_info.msize = MSIZE1; 
                decode_info.unsign_en = 1'b0;

            end

            OP_LBU:begin
                decode_info.unit = U_MEMORY;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = {16'd0, instr.payload.itype.imm};

                decode_info.mem_read = 1'b1;
                decode_info.mem_write = 1'b0;
                decode_info.msize = MSIZE1; 
                decode_info.unsign_en = 1'b1;

            end

            OP_LH:begin
                decode_info.unit = U_MEMORY;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = {16'd0, instr.payload.itype.imm};

                decode_info.mem_read = 1'b1;
                decode_info.mem_write = 1'b0;
                decode_info.msize = MSIZE2; 
                decode_info.unsign_en = 1'b0;

            end

            OP_LHU:begin
                decode_info.unit = U_MEMORY;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = {16'd0, instr.payload.itype.imm};

                decode_info.mem_read = 1'b1;
                decode_info.mem_write = 1'b0;
                decode_info.msize = MSIZE2; 
                decode_info.unsign_en = 1'b1;

            end

            OP_LW:begin
                decode_info.unit = U_MEMORY;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.mem_read = 1'b1;
                decode_info.mem_write = 1'b0;
                decode_info.msize = MSIZE4; 
                decode_info.unsign_en = 1'b0;

            end
            
              OP_LUI:begin
                decode_info.unit = U_ALU;
                decode_info.instr_type = ITYPE;

                decode_info.regA = R0;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b0;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = {instr.payload.itype.imm, 16'd0};

                decode_info.operator = AR_LU;

            end

            OP_ORI:begin
                decode_info.unit = U_ALU;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = {16'd0, instr.payload.itype.imm};

                decode_info.operator = AR_OR;

            end

            OP_RTYPE:begin
                unique case(instr.payload.rtype.funct)
                    FN_ADD:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_ADD;

                    end
                    
                    FN_ADDU:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_ADDU;

                    end

                    FN_AND:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_AND;
                        
                    end

                    FN_DIV:begin
                        decode_info.unit = U_DIV;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = R0;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b0;

                        decode_info.hilo_unsign = 0;                     
                    
                    end 

                    FN_BREAK:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = COP0;

                        decode_info.operator = AR_BR;
                    end

                    FN_DIVU:begin
                        decode_info.unit = U_DIV;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = R0;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b0;

                        decode_info.hilo_unsign = 1;                     
                    
                    end 

                    FN_JALR:begin
                        decode_info.unit = U_BRANCH;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = R0;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b0;
                        decode_info.write_en_C = 1'b1;

                        decode_info.cmp = CMP_J;
                        
                    end

                    FN_JR:begin
                        decode_info.unit = U_BRANCH;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = R0;
                        decode_info.regC = R0;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b0;
                        decode_info.write_en_C = 1'b0;

                        decode_info.cmp = CMP_J;
                        
                    end 

                    FN_MFHI:begin
                        decode_info.unit = U_HILO;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = R0;
                        decode_info.regB = R0;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b0;
                        decode_info.read_en_B = 1'b0;
                        decode_info.write_en_C = 1'b1;

                        decode_info.read_hi = 1;

                    end

                    FN_MFLO:begin
                        decode_info.unit = U_HILO;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = R0;
                        decode_info.regB = R0;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b0;
                        decode_info.read_en_B = 1'b0;
                        decode_info.write_en_C = 1'b1;
                        
                        decode_info.read_lo = 1;

                    end

                    FN_MTHI:begin
                        decode_info.unit = U_HILO;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = R0;
                        decode_info.regC = R0;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b0;
                        decode_info.write_en_C = 1'b0;
                        
                        decode_info.write_hi = 1;
                        
                    end

                    FN_MTLO:begin
                        decode_info.unit = U_HILO;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = R0;
                        decode_info.regC = R0;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b0;
                        decode_info.write_en_C = 1'b0;
                        
                        decode_info.write_lo = 1;
                        
                    end

                    FN_MULT:begin
                        decode_info.unit = U_MLT;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = R0;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b0;

                        decode_info.hilo_unsign = 0;                     
                    
                    end   

                    FN_MULTU:begin
                        decode_info.unit = U_MLT;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = R0;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b0;

                        decode_info.hilo_unsign = 1;                     
                    
                    end  

                    FN_NOR:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_NOR;                       
                    
                    end        

                    FN_OR:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_OR;                       
                    
                    end        

                    FN_SLL:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rt;
                        decode_info.regB = R0;
                        decode_info.regC = instr.payload.rtype.rd;
                        decode_info.shamt = instr.payload.rtype.shamt;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b0;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SLL;                       
                    
                    end   

                    FN_SLLV:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rt;
                        decode_info.regB = instr.payload.rtype.rs;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SLL;                       
                    
                    end   

                    FN_SLT:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SLT;                       
                    
                    end    

                    FN_SLTU:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SLTU;                       
                    
                    end 

                    FN_SRA:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rt;
                        decode_info.regB = R0;
                        decode_info.regC = instr.payload.rtype.rd;
                        decode_info.shamt = instr.payload.rtype.shamt;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b0;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SRA;                       
                    
                    end     

                    FN_SRAV:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rt;
                        decode_info.regB = instr.payload.rtype.rs;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SRA;                       
                    
                    end  

                    FN_SRL:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rt;
                        decode_info.regB = R0;
                        decode_info.regC = instr.payload.rtype.rd;
                        decode_info.shamt = instr.payload.rtype.shamt;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b0;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SRL;                       
                    
                    end  
                   
                    FN_SRLV:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rt;
                        decode_info.regB = instr.payload.rtype.rs;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SRL;                       
                    
                    end 

                    FN_SUB:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SUB;

                    end  

                    FN_SUBU:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_SUBU;

                    end  

                    FN_SYSCALL:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = COP0;

                        decode_info.operator = AR_SYS;
                    end   

                    FN_XOR:begin
                        decode_info.unit = U_ALU;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.operator = AR_XOR;

                    end   
                    
                    default: begin
                        decode_info = '0;
                        decode_info.PC = PC;
                        decode_info.RI = 1;
                    end                        

                endcase
            end

            OP_SLTI:begin
                decode_info.unit = U_ALU;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.operator = AR_SLT;
            end

            OP_SLTIU:begin
                decode_info.unit = U_ALU;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm =`SIGN_EXTEND(imm, 32);

                decode_info.operator = AR_SLTU;
            end

            OP_SW:begin
                decode_info.unit = U_MEMORY;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = instr.payload.itype.rt;
                decode_info.regC = R0;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b1;
                decode_info.write_en_C = 1'b0;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.mem_read = 1'b0;
                decode_info.mem_write = 1'b1;
                decode_info.msize = MSIZE4; 
                decode_info.unsign_en = 1'b0;

            end
            
            OP_SH:begin
                decode_info.unit = U_MEMORY;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = instr.payload.itype.rt;
                decode_info.regC = R0;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b1;
                decode_info.write_en_C = 1'b0;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.mem_read = 1'b0;
                decode_info.mem_write = 1'b1;
                decode_info.msize = MSIZE2; 
                decode_info.unsign_en = 1'b0;

            end
            
            OP_SB:begin
                decode_info.unit = U_MEMORY;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = instr.payload.itype.rt;
                decode_info.regC = R0;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b1;
                decode_info.write_en_C = 1'b0;
                decode_info.imm = `SIGN_EXTEND(imm, 32);

                decode_info.mem_read = 1'b0;
                decode_info.mem_write = 1'b1;
                decode_info.msize = MSIZE1; 
                decode_info.unsign_en = 1'b0;

            end

            OP_SP2:begin
                if(instr.payload.rtype.funct == 6'b000010) begin
                        decode_info.unit = U_MLT;
                        decode_info.instr_type = RTYPE;

                        decode_info.regA = instr.payload.rtype.rs;
                        decode_info.regB = instr.payload.rtype.rt;
                        decode_info.regC = instr.payload.rtype.rd;

                        decode_info.read_en_A = 1'b1;
                        decode_info.read_en_B = 1'b1;
                        decode_info.write_en_C = 1'b1;

                        decode_info.hilo_unsign = 0; 
                end else begin
                    decode_info.RI = 1;
                end
            end

            OP_XORI:begin
                decode_info.unit = U_ALU;
                decode_info.instr_type = ITYPE;

                decode_info.regA = instr.payload.itype.rs;
                decode_info.regB = R0;
                decode_info.regC = instr.payload.itype.rt;

                decode_info.read_en_A = 1'b1;
                decode_info.read_en_B = 1'b0;
                decode_info.write_en_C = 1'b1;
                decode_info.imm = {16'd0, instr.payload.itype.imm};

                decode_info.operator = AR_XOR;
            end  

            default:begin
                decode_info = '0;
                decode_info.PC = PC;
                decode_info.RI = 1;
            end

        endcase 

        if(~decode_input.en) decode_info = '0;
    end

    //assign dflush logic 
    always_comb begin
        d_flush = 0;
        flush_PC = '0;
        bp_info_out = bp_info;
        if(decode_input.first) begin
            if(branch_buffer.valid) begin //this is a first DS
                if(bp_info.branch_taken && branch_buffer.jump_PC != '0 && bp_info.predict_PC != branch_buffer.jump_PC) begin
                    d_flush = 1;
                    flush_PC = branch_buffer.jump_PC;
                    bp_info_out.predict_PC = branch_buffer.jump_PC;
                end
            end else begin
                if(bp_info.branch_taken && decode_info.jump_PC != '0 && bp_info.predict_PC != decode_info.jump_PC) begin
                    d_flush = 1;
                    flush_PC = decode_info.jump_PC;
                    bp_info_out.predict_PC = decode_info.jump_PC;
                end
            end
        end
    end

endmodule