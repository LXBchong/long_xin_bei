`include "common.svh"
`include "instr.svh"

module MyCore_exc(

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

    addr_t[1:0] fetch_PC, fetch_PC_nxt;
    instr_t[1:0] fetch_instr, fetch_instr_nxt;
    decode_t[1:0] decode_info, decode_info_nxt;
    logic[1:0] PC_valid, decode_en, decode_en_nxt;

    decode_t[1:0] issue_instr;
    logic[1:0] issue_cnt;
    logic queue_full, queue_empty;

    logic mem_halt, mem_addr_halt, flush, div_halt, d_flush, f2_flush;
    logic flush_f1f2, flush_f2d, flush_di, flush_q, flush_e1, flush_e2, flush_e3, stall_e1, stall_e2, stall_e3, flush_com, mem_exception, exception_flag;
 
    regid_t ra1, ra2, ra3, ra4, wa5, wa6;
    word_t rd1, rd2, rd3, rd4, wd5, wd6;
    word_t hi_data, lo_data, hi, lo;
    logic write_en1, write_en2, write_hi_en, write_lo_en, write_hi_hl, write_lo_hl;

    word_t ALU1_result, ALU2_result, AGU_result, HILO_result, COP0_result;
    logic[63:0] MLT_result, DIV_result;
    logic branch_predict_fail, eret, cp0_flush, wfirst, wsecond, DS_EXC, exception, exception_en1, exception_en2;
    addr_t BRU_link_PC, recover_PC, EPC, cur_PC, cur_PC_nxt, d_flush_PC, f2_flush_PC;
    word_t p0, p1, p2, p3;
    fetch2_input_t fetch2_input, fetch2_input_nxt;
    decode_input_t decode_input, decode_input_nxt;
    exec_pipeline_reg_t exec_p12, exec_p23, exec_p12_nxt, exec_p23_nxt;
    exec_input_t exec_input, exec_input_nxt;
    exec_result_t exec_result, exec_result_nxt;
    
    word_t ALU1_bypass_p2, ALU2_bypass_p2,ALU1_bypass_p3, ALU2_bypass_p3;
    branch_predict_t bp_info, bp_info_nxt;
    dbus_req_t dreq_nxt;
    fetch2_BP_bypass_t fetch2_BP_bypass;
    BRU_BP_bypass_t BRU_BP_bypass;

    cp0_reg_input_t cp0_reg_input;
    cp0_regfile_t cp0_reg;
    logic[7:0] cp0_wregsel;
    word_t cp0_wdata, cp0_wpc, wPC;
    exception_collector_t exception_collector;
    
    assign DS_EXC = exception_collector.ALU2_OV || exception_collector.ALU2_SYS || exception_collector.ALU2_BR
        || exception_collector.AGU_AdEL || exception_collector.AGU_AdES || exception_collector.COP0_AdEL;
    assign EPC = cp0_reg.EPC;

    //TODO: doesn't have cache yetm 
    fetch1 fetch1_ins(clk, resetn, ireq, iresp, fetch2_BP_bypass, BRU_BP_bypass, fetch2_input_nxt, branch_predict_fail, queue_full, flush, d_flush, eret, cp0_flush, f2_flush, EPC, recover_PC, d_flush_PC, f2_flush_PC);
    fetch2 fetch2_ins(fetch2_input, decode_input_nxt, fetch2_BP_bypass, queue_full, flush, eret, cp0_flush, f2_flush, f2_flush_PC);
    //fetch fetch_ins(clk, resetn, fetch_PC_nxt, fetch_instr_nxt, fetch_halt, ireq, iresp, PC_not_taken, branch_predict_fail, queue_full, flush, eret, cp0_flush, cp0_reg.EPC);

    decode decode_ins(clk, resetn, decode_input, decode_info_nxt, decode_en_nxt, d_flush, d_flush_PC);
    //decode decode_ins1(fetch_PC[0], fetch_instr[0], decode_info_nxt[0]);
    //decode decode_ins2(fetch_PC[1], fetch_instr[1], decode_info_nxt[1]);
    
    queue issue_queue_ins(clk, resetn, flush, decode_info, decode_en, issue_instr, issue_cnt, queue_full, queue_empty);
    issue issue_ins(clk, resetn, issue_instr, exec_input_nxt, issue_cnt, ra1, ra2, ra3, ra4, rd1, rd2, rd3, rd4, queue_empty, mem_halt, queue_full, div_halt, ALU1_bypass_p2, ALU1_bypass_p3, ALU2_bypass_p2, ALU2_bypass_p3, stall_e1, stall_e2, stall_e3, exception_flag);

    ALU ALU1_ins(exec_input.ALU1_input, ALU1_result, exception_collector.ALU1_OV, exception_collector.ALU1_SYS, exception_collector.ALU1_BR);
    ALU ALU2_ins(exec_input.ALU2_input, ALU2_result, exception_collector.ALU2_OV, exception_collector.ALU2_SYS, exception_collector.ALU2_BR);
    BRU BRU_ins(exec_input.BRU_input, branch_predict_fail, BRU_link_PC, recover_PC, BRU_BP_bypass, exception_collector.BRU_AdEL, exception_collector.BRU_BadVAddr, DS_EXC);
    AGU1 AGU1_ins(exec_input.AGU_input, dreq_nxt, exception_collector.AGU_AdES, exception_collector.AGU_AdEL, exception_collector.AGU_BadVAddr, cp0_flush, mem_exception);
    AGU2 AGU2_ins(clk, resetn, exec_p12.AGU_input, exec_p12.dreq, dreq, dresp, mem_halt, mem_addr_halt);
    AGU3 AGU3_ins(exec_p23.AGU_input, AGU_result, dresp, mem_halt, exception);
    HILO HILO_ins(exec_input.HILO_input, hi, lo, DIV_result, exec_input.exec_reg1.fu, write_hi_hl, write_lo_hl, HILO_result);
    DIV DIV_ins(clk, resetn, exec_input.DIV_input, div_halt, DIV_result);
    MLT1 MLT1_ins(exec_input.MLT_input, p0, p1);
    MLT2 MLT2_ins(exec_p12.MLT_in, p2, p3);
    MLT3 MLT3_ins(exec_p23.MLT_in, exec_p23.MLT_p, MLT_result);
    COP0 COP0_ins(exec_input.COP0_input, exception_collector.COP0_eret, COP0_result, cp0_wregsel, cp0_wdata, cp0_wpc, wfirst, wsecond, cp0_reg, cp0_flush, exception_collector.COP0_AdEL, exception_collector.COP0_BadVAddr);

    exhandler exhandler_ins(exec_input.exec_reg1, exec_input.exec_reg2, exception_collector, cp0_reg, cp0_reg_input, exception_en1, exception_en2, eret, ext_int);
    commit_exc commit_ins(exec_result, wa5, wa6, wd5, wd6, write_en1, write_en2, hi_data, lo_data, write_hi_en, write_lo_en, ext_int, cp0_reg, clk, resetn, debug_wb_pc, debug_wb_rf_wen, debug_wb_rf_wnum, debug_wb_rf_wdata, wPC);

    regfile regfile_ins(.*);
    hilo_reg hilo_reg_ins(.*);
    cp0_reg cp0_reg_ins(.*);

    assign exec_p12_nxt.ALU1_result = ALU1_result;
    assign exec_p12_nxt.ALU2_result = ALU2_result;
    assign exec_p12_nxt.BRU_link_PC = BRU_link_PC;
    assign exec_p12_nxt.AGU_input = exec_input.AGU_input;
    assign exec_p12_nxt.dreq = dreq_nxt;
    assign exec_p12_nxt.MLT_in = exec_input.MLT_input;
    assign exec_p12_nxt.MLT_p = {64'd0, p1, p0};
    assign exec_p12_nxt.DIV_result = DIV_result;
    assign exec_p12_nxt.exec_reg1 = exec_input.exec_reg1;
    assign exec_p12_nxt.exec_reg2 = exec_input.exec_reg2;
    assign exec_p12_nxt.write_hi = write_hi_hl;
    assign exec_p12_nxt.write_lo = write_lo_hl;
    assign exec_p12_nxt.HILO_result = HILO_result;
    assign exec_p12_nxt.COP0_result = COP0_result;
    assign exec_p12_nxt.exception_collector = exception_collector;
    assign exec_p12_nxt.exc_info.exception1_en = exception_en1;
    assign exec_p12_nxt.exc_info.exception2_en = exception_en2;
    assign exec_p12_nxt.exc_info.BRU_AdEL = exception_collector.BRU_AdEL;

    assign exec_p23_nxt.ALU1_result = exec_p12.ALU1_result;
    assign exec_p23_nxt.ALU2_result = exec_p12.ALU2_result;
    assign exec_p23_nxt.BRU_link_PC = exec_p12.BRU_link_PC;
    assign exec_p23_nxt.MLT_in = exec_p12.MLT_in;
    assign exec_p23_nxt.AGU_input = exec_p12.AGU_input;
    assign exec_p23_nxt.dreq = exec_p12.dreq;
    assign exec_p23_nxt.MLT_p = {p3, p2, exec_p12.MLT_p[1:0]};
    assign exec_p23_nxt.DIV_result = exec_p12.DIV_result;
    assign exec_p23_nxt.exec_reg1 = exec_p12.exec_reg1;
    assign exec_p23_nxt.exec_reg2 = exec_p12.exec_reg2;
    assign exec_p23_nxt.write_hi = exec_p12.write_hi;
    assign exec_p23_nxt.write_lo = exec_p12.write_lo;
    assign exec_p23_nxt.HILO_result = exec_p12.HILO_result;
    assign exec_p23_nxt.COP0_result = exec_p12.COP0_result;
    assign exec_p23_nxt.exception_collector = exec_p12.exception_collector;
    assign exec_p23_nxt.exc_info.exception1_en = exec_p12.exc_info.exception1_en;
    assign exec_p23_nxt.exc_info.exception2_en = exec_p12.exc_info.exception2_en;
    assign exec_p23_nxt.exc_info.BRU_AdEL = exec_p12.exc_info.BRU_AdEL;

    assign exec_result_nxt.ALU1_result = exec_p23.ALU1_result;
    assign exec_result_nxt.ALU2_result = exec_p23.ALU2_result;
    assign exec_result_nxt.BRU_link_PC = exec_p23.BRU_link_PC;
    assign exec_result_nxt.AGU_result = AGU_result;
    assign exec_result_nxt.MLT_result = MLT_result;
    assign exec_result_nxt.DIV_result = exec_p23.DIV_result;
    assign exec_result_nxt.write_hi = exec_p23.write_hi;
    assign exec_result_nxt.write_lo = exec_p23.write_lo;
    assign exec_result_nxt.HILO_result = exec_p23.HILO_result;
    assign exec_result_nxt.exec_reg1 = exec_p23.exec_reg1;
    assign exec_result_nxt.exec_reg2 = exec_p23.exec_reg2;
    assign exec_result_nxt.COP0_result = exec_p23.COP0_result;
    assign exec_result_nxt.exception_collector = exec_p23.exception_collector;
    assign exec_result_nxt.exc_info.exception1_en = exec_p23.exc_info.exception1_en;
    assign exec_result_nxt.exc_info.exception2_en = exec_p23.exc_info.exception2_en;
    assign exec_result_nxt.exc_info.BRU_AdEL = exec_p23.exc_info.BRU_AdEL;


    //TODO more result to be done 
    assign ALU1_bypass_p2 = exec_p12.ALU1_result;
    assign ALU2_bypass_p2 = exec_p12.ALU2_result;
    assign ALU1_bypass_p3 = exec_p23.ALU1_result;
    assign ALU2_bypass_p3 = exec_p23.ALU2_result;

    assign exception_collector.COP0_first = wfirst;
    assign exception_collector.COP0_second = wsecond;
    assign exception = exec_p23.exception_collector.AGU_AdES || exec_p23.exception_collector.AGU_AdEL;
    assign mem_exception = exec_p23.exception_collector.AGU_AdES || exec_p23.exception_collector.AGU_AdEL
        || exec_p12.exception_collector.AGU_AdES || exec_p12.exception_collector.AGU_AdEL
         || exec_result.exception_collector.AGU_AdES || exec_result.exception_collector.AGU_AdEL;

    assign exception_flag = exception_collector.ALU1_OV || exception_collector.ALU2_OV || exec_input.exec_reg1.RI || exec_input.exec_reg2.RI
        || exception_collector.AGU_AdEL || exception_collector.BRU_AdEL || exception_collector.COP0_AdEL
        || exception_collector.AGU_AdES || exception_collector.ALU1_SYS || exception_collector.ALU2_SYS 
        || exception_collector.ALU1_BR || exception_collector.ALU2_BR || exception_collector.COP0_eret
        || exec_p12.exception_collector.ALU1_OV || exec_p12.exception_collector.ALU2_OV ||  exec_p12.exec_reg1.RI || exec_p12.exec_reg2.RI
        || exec_p12.exception_collector.AGU_AdEL || exec_p12.exception_collector.BRU_AdEL || exec_p12.exception_collector.COP0_AdEL
        || exec_p12.exception_collector.AGU_AdES ||exec_p12.exception_collector.ALU1_SYS || exec_p12.exception_collector.ALU2_SYS 
        || exec_p12.exception_collector.ALU1_BR || exec_p12.exception_collector.ALU2_BR || exec_p12.exception_collector.COP0_eret        
        || exec_p23.exception_collector.ALU1_OV || exec_p23.exception_collector.ALU2_OV ||  exec_p23.exec_reg1.RI || exec_p23.exec_reg2.RI
        || exec_p23.exception_collector.AGU_AdEL || exec_p23.exception_collector.BRU_AdEL || exec_p23.exception_collector.COP0_AdEL
        || exec_p23.exception_collector.AGU_AdES ||exec_p23.exception_collector.ALU1_SYS || exec_p23.exception_collector.ALU2_SYS 
        || exec_p23.exception_collector.ALU1_BR || exec_p23.exception_collector.ALU2_BR || exec_p23.exception_collector.COP0_eret;
        
    assign flush = branch_predict_fail || cp0_flush || eret;
    //assign flush = branch_predict_fail;
    assign flush_f1f2 = branch_predict_fail || cp0_flush || eret || f2_flush || d_flush;
    assign flush_f2d = branch_predict_fail || cp0_flush || eret || d_flush;
    assign flush_di = branch_predict_fail || cp0_flush || eret;
    assign flush_q = branch_predict_fail || cp0_flush || eret;
    //assign flush_e1 = cp0_flush || eret;
    //assign flush_e2 = cp0_flush || eret || stall_e1;
    //assign flush_e3 = cp0_flush || eret || stall_e2;
    assign flush_e1 = 0;
    assign flush_e2 = stall_e1;
    assign flush_e3 = stall_e2;
    assign flush_com = mem_halt || stall_e3;
    
    //assign stall fetch = queue_full
    assign stall_e1 = div_halt || mem_addr_halt || mem_halt;
    assign stall_e2 = mem_addr_halt || mem_halt;
    assign stall_e3 = mem_halt;

    always_ff @(posedge clk) begin
        if(~resetn) begin
            fetch2_input <= '0;
            decode_input <= '0;
            decode_info <= '0;
            decode_en <= '0;
            exec_input <= '0;
            exec_p12 <= '0;
            exec_p23 <= '0;
            exec_result <= '0;

        end else begin
            fetch2_input <= flush_f1f2 ? '0 : fetch2_input_nxt;
            decode_input <= flush_f2d ? '0 : decode_input_nxt;
            decode_info <= flush_di ? '0 : decode_info_nxt;
            decode_en <= flush_di ? '0 : decode_en_nxt;
            
            if(~stall_e1)
                exec_input <= flush_e1 ? '0 : exec_input_nxt;
            
            if(~stall_e2)
                exec_p12 <= flush_e2 ? '0 : exec_p12_nxt;
                
            if(~stall_e3)
                exec_p23 <= flush_e3 ? '0 : exec_p23_nxt;
                
            if(flush_com)
                exec_result <= '0;
            else 
                exec_result <= exec_result_nxt;
                
        end
    end    
    
endmodule