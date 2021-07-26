`include "common.svh"
`include "instr.svh"

module commit(
    input exec_reg_t exec_reg1, exec_reg2,
    input word_t ALU1_result, ALU2_result, MMU_out, HILO_result, COP0_result,
    input addr_t BRU_link_PC,
    input logic[63:0] MLT_result, DIV_result,
    input logic write_hi_hl, write_lo_hl,

    output regid_t wa5, wa6,
    output word_t wd5, wd6,  
    output logic write_en1, write_en2,
    output word_t hi_data, lo_data,
    output logic write_hi, write_lo,

    input exception_collector_t exception_collector,
    output cp0_reg_input_t cp0_reg_input,
    input logic[5:0] ext_int,
    input cp0_regfile_t cp0_reg,
    output logic eret,
    
    input logic clk, resetn,
    output logic[31:0] debug_wb_pc        ,
    output logic[3:0] debug_wb_rf_wen     ,
    output logic[4:0] debug_wb_rf_wnum    ,
    output logic[31:0] debug_wb_rf_wdata  
);

        //hanlde exception
    logic exception1_en, exception2_en, BD;
    addr_t EPC, BadVAddr;
    ecode_t ExeCode;

    logic[7:0] interrupt_info;
    
    assign eret = exception_collector.COP0_eret && ~exception_collector.COP0_AdEL;
    assign interrupt_info = ({ext_int, 2'b00} | cp0_reg.Cause.IP | {cp0_reg.Cause.TI, 7'b0}) & cp0_reg.Status.IM;
    //hardware write to cop0
    always_comb begin
        exception1_en = 0;
        exception2_en = 0;
        BD = 0;
        EPC = '0;
        BadVAddr = '0;
        ExeCode = EX_NONE;

        if(interrupt_info && exec_reg1.en && ~cp0_reg.Status.EXL) begin
            exception1_en = 1;
            EPC = exec_reg1.PC + 32'd4;
            ExeCode = EX_INT;
        end else if(exec_reg1.en && exception_collector.BRU_AdEL
            && (~exception_collector.ALU2_BR && ~exception_collector.ALU2_SYS && ~exception_collector.ALU2_OV
            && ~exception_collector.COP0_AdEL && ~exception_collector.MMU_AdEL && ~exception_collector.MMU_AdES
            && ~exec_reg2.RI)) begin
            exception1_en = 1;
            EPC = exception_collector.BRU_BadVAddr;
            ExeCode = EX_ADEL;
            BadVAddr = exception_collector.BRU_BadVAddr;
        end else if(exec_reg1.en && exception_collector.COP0_AdEL && exception_collector.COP0_first) begin
            exception1_en = 1;
            EPC = exception_collector.COP0_BadVAddr;
            ExeCode = EX_ADEL;
            BadVAddr = exception_collector.COP0_BadVAddr;
        end else if(exec_reg1.en && exec_reg1.RI) begin
            exception1_en = 1;
            EPC = exec_reg1.PC;
            ExeCode = EX_RI;
        end else if(exec_reg1.en && exception_collector.ALU1_OV) begin
            exception1_en = 1;
            EPC = exec_reg1.PC;
            ExeCode = EX_OV;
        end else if(exec_reg1.en && exception_collector.ALU1_SYS) begin
            exception1_en = 1;
            EPC = exec_reg1.PC;
            ExeCode = EX_SYS;
        end else if(exec_reg1.en && exception_collector.ALU1_BR) begin
            exception1_en = 1;
            EPC = exec_reg1.PC;
            ExeCode = EX_BP;
        end else if(exec_reg1.en && exec_reg1.fu == MMU && exception_collector.MMU_AdEL) begin
            exception1_en = 1;
            EPC = exec_reg1.PC;
            ExeCode = EX_ADEL;
            BadVAddr = exception_collector.MMU_BadVAddr;
        end else if(exec_reg1.en &&  exec_reg1.fu == MMU && exception_collector.MMU_AdES) begin
            exception1_en = 1;
            EPC = exec_reg1.PC;
            ExeCode = EX_ADES;
            BadVAddr = exception_collector.MMU_BadVAddr;
        end else if(exec_reg2.en && exception_collector.COP0_AdEL && exception_collector.COP0_second) begin
            exception2_en = 1;
            EPC = exception_collector.COP0_BadVAddr;
            ExeCode = EX_ADEL;
            BadVAddr = exception_collector.COP0_BadVAddr;
        end else if(exec_reg2.en && exec_reg2.RI) begin
            exception2_en = 1;
            EPC = exec_reg2.PC;
            ExeCode = EX_RI;
            if(exec_reg1.fu == BRU)begin
                EPC = exec_reg2.PC - 32'd4;
                BD = 1;
            end
        end else if(exec_reg2.en && exception_collector.ALU2_OV) begin
            exception2_en = 1;
            EPC = exec_reg2.PC;
            ExeCode = EX_OV;
            if(exec_reg1.fu == BRU)begin
                EPC = exec_reg2.PC - 32'd4;
                BD = 1;
            end
        end else if(exec_reg2.en && exception_collector.ALU2_SYS) begin
            exception2_en = 1;
            EPC = exec_reg2.PC;
            ExeCode = EX_SYS;
            if(exec_reg1.fu == BRU)begin
                EPC = exec_reg2.PC - 32'd4;
                BD = 1;
            end
        end else if(exec_reg2.en && exception_collector.ALU2_BR) begin
            exception2_en = 1;
            EPC = exec_reg2.PC;
            ExeCode = EX_BP;
            if(exec_reg1.fu == BRU)begin
                EPC = exec_reg2.PC - 32'd4;
                BD = 1;
            end
        end else if(exec_reg2.en && exception_collector.MMU_AdEL) begin
            exception2_en = 1;
            EPC = exec_reg2.PC;
            ExeCode = EX_ADEL;
            BadVAddr = exception_collector.MMU_BadVAddr;
            if(exec_reg1.fu == BRU)begin
                EPC = exec_reg2.PC - 32'd4;
                BD = 1;
            end
        end else if(exec_reg2.en && exception_collector.MMU_AdES) begin
            exception2_en = 1;
            EPC = exec_reg2.PC;
            ExeCode = EX_ADES;
            BadVAddr = exception_collector.MMU_BadVAddr;
            if(exec_reg1.fu == BRU)begin
                EPC = exec_reg2.PC - 32'd4;
                BD = 1;
            end
        end
    end
    
    logic write1_valid, write2_valid;
    
    assign write1_valid = exec_reg1.en 
        && (~exception1_en || (exception1_en && exception_collector.BRU_AdEL));
    assign write2_valid = exec_reg2.en 
        && (~exception1_en && ~exception2_en);

    //write reg
    always_comb begin
        wa5 = R0;
        wa6 = R0;
        wd5 = '0;
        wd6 = '0;
        write_en1 = 0;
        write_en2 = 0;
        
        if(write1_valid && exec_reg1.target_reg != R0) begin
            write_en1 = 1;
            unique case(exec_reg1.fu)
                ALU1:begin
                    wa5 = exec_reg1.target_reg;
                    wd5 = ALU1_result;
                end

                BRU:begin
                    wa5 = RA;
                    wd5 = BRU_link_PC;
                end

                MMU:begin
                    wa5 = exec_reg1.target_reg;
                    wd5 = MMU_out;
                end

                HILO:begin
                    wa5 = exec_reg1.target_reg;
                    wd5 = HILO_result;
                end

                CP0:begin
                    wa5 = exec_reg1.target_reg;
                    wd5 = COP0_result;
                end

                default: write_en1 = 0;

            endcase 
        end

        if(write2_valid && exec_reg2.target_reg != R0) begin
            write_en2 = 1;
            unique case(exec_reg2.fu)
                ALU2:begin
                    wa6 = exec_reg2.target_reg; 
                    wd6 = ALU2_result;
                end

                MMU:begin
                    wa6 = exec_reg2.target_reg;
                    wd6 = MMU_out;
                end

                HILO:begin
                    wa6 = exec_reg2.target_reg;
                    wd6 = HILO_result;
                end

                CP0:begin
                    wa6 = exec_reg2.target_reg;
                    wd6 = COP0_result;
                end

                default: write_en2 = 0;

            endcase
        end
    end

    //write hilo
    always_comb begin
        write_hi = 0;
        write_lo = 0;
        hi_data = '0;
        lo_data = '0;
        if(write2_valid && exec_reg2.fu == MLT)begin
            write_hi = 1;
            write_lo = 1;
            hi_data = MLT_result[63:32];
            lo_data = MLT_result[31:0];
        end else if(write2_valid && exec_reg2.fu == DIV)begin
            write_hi = 1;
            write_lo = 1;
            hi_data = DIV_result[63:32];
            lo_data = DIV_result[31:0];
        end else if(write2_valid && exec_reg2.fu == HILO && (write_hi_hl || write_lo_hl))begin
            write_hi = write_hi_hl;
            write_lo = write_lo_hl;
            hi_data = HILO_result;
            lo_data = HILO_result;
        end else if(write1_valid && exec_reg1.fu == MLT)begin
            write_hi = 1;
            write_lo = 1;
            hi_data = MLT_result[63:32];
            lo_data = MLT_result[31:0];
        end else if(write1_valid && exec_reg1.fu == DIV)begin
            write_hi = 1;
            write_lo = 1;
            hi_data = DIV_result[63:32];
            lo_data = DIV_result[31:0];
        end else if(write1_valid && exec_reg1.fu == HILO && (write_hi_hl || write_lo_hl))begin
            write_hi = write_hi_hl;
            write_lo = write_lo_hl;
            hi_data = HILO_result;
            lo_data = HILO_result;
        end
    end

    assign cp0_reg_input.exception_en = exception1_en | exception2_en;
    assign cp0_reg_input.BD = BD;
    assign cp0_reg_input.EPC = EPC;
    assign cp0_reg_input.BadVAddr = BadVAddr;
    assign cp0_reg_input.ExeCode = ExeCode;

    addr_t debug_pc1, debug_pc2;
    logic debug_wen1, debug_wen2, debug1_valid, debug2_valid;
    regid_t debug_wnum1, debug_wnum2;
    word_t debug_data1, debug_data2;
    logic[1:0] debug_en;
    
    assign debug1_valid = write1_valid;
    assign debug2_valid = write2_valid;

    always_comb begin
        debug_pc1 = '0;
        debug_pc2 = '0;
        debug_wen1 = '0;
        debug_wen2 = '0;
        debug_wnum1 = R0;
        debug_wnum2 = R0;
        debug_data1 = '0;
        debug_data2 = '0;
        debug_en = '0;

        if(debug1_valid) begin
            debug_en[0] = 1;
            debug_pc1 = exec_reg1.PC;
            debug_wen1 = exec_reg1.target_reg == R0 ? 0 : 1;
            debug_wnum1 = exec_reg1.target_reg;
            debug_data1 = exec_reg1.target_reg == R0 ? '0 : wd5;
        end

        if(debug2_valid) begin
            debug_en[1] = 1;
            debug_pc2 = exec_reg2.PC;
            debug_wen2 = exec_reg2.target_reg == R0 ? 0 : 1;
            debug_wnum2 = exec_reg2.target_reg;
            debug_data2 = exec_reg2.target_reg == R0 ? '0 : wd6;
        end
    end

    debug_queue debug_queue_ins(.*);

endmodule