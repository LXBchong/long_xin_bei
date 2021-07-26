`include "common.svh"
`include "instr.svh"

module MyCore(

    output ibus_req_t  ireq,
    output dbus_req_t  dreq,
    input  ibus_resp_t iresp,
    input  dbus_resp_t dresp,
    
    input logic clk         ,
    input logic resetn      ,
    input logic[5:0] ext_int,

    //debug
    output logic[31:0] debug_wb_pc        ,
    output logic[3:0] debug_wb_rf_wen     ,
    output logic[4:0] debug_wb_rf_wnum    ,
    output logic[31:0] debug_wb_rf_wdata 
);


    addr_t[3:0] fetch_PC, fetch_PC_nxt;
    instr_t[3:0] fetch_instr, fetch_instr_nxt;
    decode_t[3:0] decode_info, decode_info_nxt;
    logic[3:0] decode_en;

    decode_t[1:0] issue_instr;
    logic[1:0] issue_cnt;
    logic queue_full, queue_empty;

    logic mem_halt, fetch_halt, flush, mlt_halt, div_halt;
 
    regid_t ra1, ra2, ra3, ra4, wa5, wa6;
    word_t rd1, rd2, rd3, rd4, wd5, wd6;
    word_t hi_data, lo_data, hi, lo, hi_data_hl, lo_data_hl;
    logic write_en1, write_en2, write_hi_en, write_lo_en, write_hi_hl, write_hi_hl_nxt, write_lo_hl, write_lo_hl_nxt;

    ALU_input_t ALU1_input, ALU2_input, ALU1_input_nxt, ALU2_input_nxt;
    BRU_input_t BRU_input, BRU_input_nxt;
    MMU_input_t MMU_input, MMU_input_nxt;
    HILO_input_t HILO_input, HILO_input_nxt;
    MLT_input_t MLT_input, MLT_input_nxt;
    DIV_input_t DIV_input, DIV_input_nxt;
    COP0_input_t COP0_input, COP0_input_nxt;
    exec_reg_t exec_reg1, exec_reg2, exec_reg1_nxt, exec_reg2_nxt;
    exec_reg_t exec_reg1_p2, exec_reg2_p2, exec_reg1_p2_nxt, exec_reg2_p2_nxt;
    word_t ALU1_result, ALU2_result, ALU1_result_nxt, ALU2_result_nxt, MMU_out, MMU_out_nxt, HILO_result, HILO_result_nxt, COP0_result, COP0_result_nxt;
    logic[63:0] MLT_result, DIV_result, MLT_result_nxt, DIV_result_nxt;
    logic branch_predict_fail, eret, cp0_flush, wfirst, wsecond, DS_EXC;
    addr_t BRU_link_PC, BRU_link_PC_nxt, PC_not_taken;
    cp0_reg_input_t cp0_reg_input;
    cp0_regfile_t cp0_reg;
    logic[7:0] cp0_wregsel;
    word_t cp0_wdata;
    exception_collector_t exception_collector,  exception_collector_nxt;
    
    assign DS_EXC = exception_collector_nxt.ALU2_OV || exception_collector_nxt.ALU2_SYS || exception_collector_nxt.ALU2_BR
        || exception_collector_nxt.MMU_AdEL || exception_collector_nxt.MMU_AdES || exception_collector_nxt.COP0_AdEL;

    //TODO: doesn't have cache yet
    fetch fetch_ins(clk, resetn, fetch_PC_nxt, fetch_instr_nxt, fetch_halt, ireq, iresp, PC_not_taken, branch_predict_fail, queue_full, flush, eret, cp0_flush, cp0_reg.EPC);

    decode decode_ins1(fetch_PC[0], fetch_instr[0], decode_info_nxt[0]);
    decode decode_ins2(fetch_PC[1], fetch_instr[1], decode_info_nxt[1]);
    decode decode_ins3(fetch_PC[2], fetch_instr[2], decode_info_nxt[2]);
    decode decode_ins4(fetch_PC[3], fetch_instr[3], decode_info_nxt[3]);

    assign decode_en[0] = decode_info[0].PC != '0 ? 1 : 0;
    assign decode_en[1] = decode_info[1].PC != '0 ? 1 : 0;
    assign decode_en[2] = decode_info[2].PC != '0 ? 1 : 0;
    assign decode_en[3] = decode_info[3].PC != '0 ? 1 : 0;
    
    queue issue_queue_ins(clk, resetn, flush, decode_info, decode_en, issue_instr, issue_cnt, queue_full, queue_empty, fetch_halt);
    issue issue_ins(clk, resetn, issue_instr, ALU1_input_nxt, ALU2_input_nxt, BRU_input_nxt, MMU_input_nxt, HILO_input_nxt, MLT_input_nxt, DIV_input_nxt, COP0_input_nxt, exec_reg1_nxt, exec_reg2_nxt, issue_cnt, ra1, ra2, ra3, ra4, rd1, rd2, rd3, rd4, queue_empty, fetch_halt, mem_halt, queue_full, mlt_halt, div_halt);

    regfile regfile_ins(.*);
    hilo_reg hilo_reg_ins(.*);
    cp0_reg cp0_reg_ins(.*);

    ALU ALU1_ins(ALU1_input, ALU1_result_nxt, exception_collector_nxt.ALU1_OV, exception_collector_nxt.ALU1_SYS, exception_collector_nxt.ALU1_BR);
    ALU ALU2_ins(ALU2_input, ALU2_result_nxt, exception_collector_nxt.ALU2_OV, exception_collector_nxt.ALU2_SYS, exception_collector_nxt.ALU2_BR);
    BRU BRU_ins(BRU_input, branch_predict_fail, BRU_link_PC_nxt, PC_not_taken, exception_collector_nxt.BRU_AdEL, exception_collector_nxt.BRU_BadVAddr, DS_EXC);
    MMU MMU_ins(MMU_input, MMU_out_nxt, dreq, dresp, mem_halt, exception_collector_nxt.MMU_AdES, exception_collector_nxt.MMU_AdEL, exception_collector_nxt.MMU_BadVAddr, cp0_flush);
    HILO HILO_ins(HILO_input, hi, lo, MLT_result_nxt, DIV_result_nxt, exec_reg1.fu, write_hi_hl_nxt, write_lo_hl_nxt, HILO_result_nxt);
    MLT MLT_ins(clk, resetn, MLT_input, mlt_halt, MLT_result_nxt);
    DIV DIV_ins(clk, resetn, DIV_input, div_halt, DIV_result_nxt);
    COP0 COP0_ins(COP0_input, exception_collector_nxt.COP0_eret, COP0_result_nxt, cp0_wregsel, cp0_wdata, wfirst, wsecond, cp0_reg, cp0_flush, exception_collector_nxt.COP0_AdEL, exception_collector_nxt.COP0_BadVAddr);

    commit commit_ins(exec_reg1_p2, exec_reg2_p2, ALU1_result, ALU2_result, MMU_out, HILO_result, COP0_result, BRU_link_PC, MLT_result, DIV_result, write_hi_hl, write_lo_hl, wa5, wa6, wd5, wd6, write_en1, write_en2, hi_data, lo_data, write_hi_en, write_lo_en, exception_collector, cp0_reg_input, ext_int, cp0_reg, eret, clk, resetn, debug_wb_pc, debug_wb_rf_wen, debug_wb_rf_wnum, debug_wb_rf_wdata);

    assign exec_reg1_p2_nxt = exec_reg1;
    assign exec_reg2_p2_nxt = exec_reg2;
    assign exception_collector_nxt.COP0_first = wfirst;
    assign exception_collector_nxt.COP0_second = wsecond;

    assign flush = branch_predict_fail || cp0_flush || eret;

    always_ff @(posedge clk) begin
        if(~resetn) begin
            fetch_PC <= '0;
            fetch_instr <= '0;
            decode_info <= '0;

        end else if(flush) begin
            fetch_PC <= '0;
            fetch_instr <= '0;
            decode_info <= '0;
            exec_reg1_p2 <= '0;
            exec_reg2_p2 <= '0;
            if(mem_halt) begin
            end else begin
                ALU1_input <= '0;
                ALU2_input <= '0;
                MMU_input <= '0;
                BRU_input <= '0;
                HILO_input <= '0;
                MLT_input <= '0;
                DIV_input <= '0;
                COP0_input <= '0;
                exec_reg1 <= '0;
                exec_reg2 <= '0;
                
                if(cp0_flush || eret)begin
                    exec_reg1_p2 <= '0;
                    exec_reg2_p2 <= '0;
                    ALU1_result <= '0;
                    ALU2_result <= '0;
                    MMU_out <= '0;
                    BRU_link_PC <= '0;
                    HILO_result <= '0;
                    MLT_result <= '0;
                    DIV_result <= '0;
                    COP0_result <= '0;
                    write_hi_hl <= '0;
                    write_lo_hl <= '0;
                    exception_collector <= '0;
                end else begin
                    exec_reg1_p2 <= exec_reg1_p2_nxt;
                    exec_reg2_p2 <= exec_reg2_p2_nxt;
                    ALU1_result <= ALU1_result_nxt;
                    ALU2_result <= ALU2_result_nxt;
                    MMU_out <= MMU_out_nxt;
                    BRU_link_PC <= BRU_link_PC_nxt;
                    HILO_result <= HILO_result_nxt;
                    MLT_result <= MLT_result_nxt;
                    DIV_result <= DIV_result_nxt;
                    COP0_result <= COP0_result_nxt;
                    write_hi_hl <= write_hi_hl_nxt;
                    write_lo_hl <= write_lo_hl_nxt;
                    exception_collector <= exception_collector_nxt;
                end
            end
            
        end else if(mem_halt || mlt_halt || div_halt) begin
            fetch_PC <= fetch_PC_nxt;
            fetch_instr <= fetch_instr_nxt;
            decode_info <= decode_info_nxt;
            exec_reg1_p2 <= '0;
            exec_reg2_p2 <= '0;
            
        end else begin
            fetch_PC <= fetch_PC_nxt;
            fetch_instr <= fetch_instr_nxt;
            decode_info <= decode_info_nxt;

            ALU1_input <= ALU1_input_nxt;
            ALU2_input <= ALU2_input_nxt;
            MMU_input <= MMU_input_nxt;
            BRU_input <= BRU_input_nxt;
            HILO_input <= HILO_input_nxt;
            MLT_input <= MLT_input_nxt;
            DIV_input <= DIV_input_nxt;
            COP0_input <= COP0_input_nxt;
            exec_reg1 <= exec_reg1_nxt;
            exec_reg2 <= exec_reg2_nxt;
            exec_reg1_p2 <= exec_reg1_p2_nxt;
            exec_reg2_p2 <= exec_reg2_p2_nxt;
            ALU1_result <= ALU1_result_nxt;
            ALU2_result <= ALU2_result_nxt;
            MMU_out <= MMU_out_nxt;
            BRU_link_PC <= BRU_link_PC_nxt;
            HILO_result <= HILO_result_nxt;
            MLT_result <= MLT_result_nxt;
            DIV_result <= DIV_result_nxt;
            COP0_result <= COP0_result_nxt;
            write_hi_hl <= write_hi_hl_nxt;
            write_lo_hl <= write_lo_hl_nxt;
            exception_collector <= exception_collector_nxt;
        end
    end

endmodule