`include "common.svh"
`include "instr.svh"

module commit_exc(
    input exec_result_t exec_result,

    output regid_t wa5, wa6,
    output word_t wd5, wd6,  
    output logic write_en1, write_en2,
    output word_t hi_data, lo_data,
    output logic write_hi, write_lo,

    input logic[5:0] ext_int,
    input cp0_regfile_t cp0_reg,
    
    input logic clk, resetn,
    output logic[31:0] debug_wb_pc        ,
    output logic[3:0] debug_wb_rf_wen     ,
    output logic[4:0] debug_wb_rf_wnum    ,
    output logic[31:0] debug_wb_rf_wdata,
    input addr_t wPC  
);

    exec_reg_t exec_reg1, exec_reg2;
    word_t ALU1_result, ALU2_result, AGU_result, HILO_result, COP0_result;
    addr_t BRU_link_PC;
    logic[63:0] MLT_result, DIV_result;
    logic write_hi_hl, write_lo_hl;

    assign exec_reg1 = exec_result.exec_reg1;
    assign exec_reg2 = exec_result.exec_reg2;
    assign ALU1_result = exec_result.ALU1_result;
    assign ALU2_result = exec_result.ALU2_result;
    assign AGU_result = exec_result.AGU_result;
    assign HILO_result = exec_result.HILO_result;
    assign BRU_link_PC = exec_result.BRU_link_PC;
    assign MLT_result = exec_result.MLT_result;
    assign DIV_result = exec_result.DIV_result;
    assign COP0_result = exec_result.COP0_result;
    assign write_hi_hl = exec_result.write_hi;
    assign write_lo_hl = exec_result.write_lo;
    assign exception_collector = exec_result.exception_collector;

    //hanlde exception
    logic exception1_en, exception2_en, BRU_AdEl;
    assign exception1_en = exec_result.exc_info.exception1_en;
    assign exception2_en = exec_result.exc_info.exception2_en;
    assign BRU_AdEL = exec_result.exc_info.BRU_AdEL;

    logic write1_valid, write2_valid;
    
    assign write1_valid = exec_reg1.en 
        && (~exception1_en || (exception1_en && BRU_AdEL));
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

                AGU:begin
                    wa5 = exec_reg1.target_reg;
                    wd5 = AGU_result;
                end

                HILO:begin
                    wa5 = exec_reg1.target_reg;
                    wd5 = HILO_result;
                end

                CP0:begin
                    wa5 = exec_reg1.target_reg;
                    wd5 = COP0_result;
                end
                
                MLT:begin
                    wa5 = exec_reg1.target_reg;
                    wd5 = MLT_result[31:0];
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

                AGU:begin
                    wa6 = exec_reg2.target_reg;
                    wd6 = AGU_result;
                end

                HILO:begin
                    wa6 = exec_reg2.target_reg;
                    wd6 = HILO_result;
                end

                CP0:begin
                    wa6 = exec_reg2.target_reg;
                    wd6 = COP0_result;
                end 
                
                MLT:begin
                    wa6 = exec_reg2.target_reg;
                    wd6 = MLT_result[31:0];
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