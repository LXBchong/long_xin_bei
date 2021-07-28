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

    addr_t[1:0] fetch_PC, fetch_PC_nxt;
    instr_t[1:0] fetch_instr, fetch_instr_nxt;
    decode_t[1:0] decode_info, decode_info_nxt;
    logic[1:0] decode_en;

    decode_t[1:0] issue_instr;
    logic[1:0] issue_cnt;
    logic queue_full, queue_empty;

    logic mem_halt, fetch_halt, flush, div_halt;
 
    regid_t ra1, ra2, ra3, ra4, wa5, wa6;
    word_t rd1, rd2, rd3, rd4, wd5, wd6;
    word_t hi_data, lo_data, hi, lo;
    logic write_en1, write_en2, write_hi_en, write_lo_en, write_hi_hl, write_lo_hl;

    word_t ALU1_result, ALU2_result, MMU_out, HILO_result, COP0_result;
    logic[63:0] MLT_result, DIV_result;
    logic branch_predict_fail, eret, cp0_flush, wfirst, wsecond, DS_EXC;
    addr_t BRU_link_PC, PC_not_taken, EPC, cur_PC, cur_PC_nxt;
    word_t p0, p1, p2, p3;
    exec_pipeline_reg_t exec_p12, exec_p23, exec_p12_nxt, exec_p23_nxt;
    exec_input_t exec_input, exec_input_nxt;
    exec_result_t exec_result, exec_result_nxt;
    
    word_t ALU1_bypass_p1, ALU2_bypass_p1,ALU1_bypass_p2, ALU2_bypass_p2,ALU1_bypass_p3, ALU2_bypass_p3;
    
    cp0_reg_input_t cp0_reg_input;
    cp0_regfile_t cp0_reg;
    logic[7:0] cp0_wregsel;
    word_t cp0_wdata;
    exception_collector_t exception_collector,  exception_collector_nxt;
    
    assign DS_EXC = 0;
    assign EPC = cp0_reg.EPC;

    //TODO: doesn't have cache yet
    fetch1 fetch1_ins(.*);
    fetch2 fetch2_ins(clk, resetn, cur_PC, fetch_PC_nxt, fetch_instr_nxt, fetch_halt, iresp, queue_full, flush, eret, cp0_flush);
    //fetch fetch_ins(clk, resetn, fetch_PC_nxt, fetch_instr_nxt, fetch_halt, ireq, iresp, PC_not_taken, branch_predict_fail, queue_full, flush, eret, cp0_flush, cp0_reg.EPC);

    decode decode_ins1(fetch_PC[0], fetch_instr[0], decode_info_nxt[0]);
    decode decode_ins2(fetch_PC[1], fetch_instr[1], decode_info_nxt[1]);

    assign decode_en[0] = decode_info[0].PC != '0 ? 1 : 0;
    assign decode_en[1] = decode_info[1].PC != '0 ? 1 : 0;
    
    queue issue_queue_ins(clk, resetn, flush, decode_info, decode_en, issue_instr, issue_cnt, queue_full, queue_empty, fetch_halt);
    issue issue_ins(clk, resetn, issue_instr, exec_input_nxt, issue_cnt, ra1, ra2, ra3, ra4, rd1, rd2, rd3, rd4, queue_empty, fetch_halt, mem_halt, queue_full, div_halt, ALU1_bypass_p1, ALU2_bypass_p1, ALU1_bypass_p2, ALU2_bypass_p2, ALU1_bypass_p3, ALU2_bypass_p3);

    regfile regfile_ins(.*);
    hilo_reg hilo_reg_ins(.*);
    cp0_reg cp0_reg_ins(.*);

    assign exec_p12_nxt.ALU1_result = ALU1_result;
    assign exec_p12_nxt.ALU2_result = ALU2_result;
    assign exec_p12_nxt.BRU_link_PC = BRU_link_PC;
    assign exec_p12_nxt.MMU_result  = MMU_out;
    assign exec_p12_nxt.MLT_in = exec_input.MLT_input;
    assign exec_p12_nxt.MLT_p = {64'd0, p1, p0};
    assign exec_p12_nxt.DIV_result = DIV_result;
    assign exec_p12_nxt.exec_reg1 = exec_input.exec_reg1;
    assign exec_p12_nxt.exec_reg2 = exec_input.exec_reg2;
    assign exec_p12_nxt.write_hi = write_hi_hl;
    assign exec_p12_nxt.write_lo = write_lo_hl;
    assign exec_p12_nxt.HILO_result = HILO_result;
    

    assign exec_p23_nxt.ALU1_result = exec_p12.ALU1_result;
    assign exec_p23_nxt.ALU2_result = exec_p12.ALU2_result;
    assign exec_p23_nxt.BRU_link_PC = exec_p12.BRU_link_PC;
    assign exec_p23_nxt.MMU_result  = exec_p12.MMU_result;
    assign exec_p23_nxt.MLT_in = exec_p12.MLT_in;
    assign exec_p23_nxt.MLT_p = {p3, p2, exec_p12.MLT_p[1:0]};
    assign exec_p23_nxt.DIV_result = exec_p12.DIV_result;
    assign exec_p23_nxt.exec_reg1 = exec_p12.exec_reg1;
    assign exec_p23_nxt.exec_reg2 = exec_p12.exec_reg2;
    assign exec_p23_nxt.write_hi = exec_p12.write_hi;
    assign exec_p23_nxt.write_lo = exec_p12.write_lo;
    assign exec_p23_nxt.HILO_result = exec_p12.HILO_result;

    assign exec_result_nxt.ALU1_result = exec_p23.ALU1_result;
    assign exec_result_nxt.ALU2_result = exec_p23.ALU2_result;
    assign exec_result_nxt.BRU_link_PC = exec_p23.BRU_link_PC;
    assign exec_result_nxt.MMU_result  = exec_p23.MMU_result;
    assign exec_result_nxt.MLT_result = MLT_result;
    assign exec_result_nxt.DIV_result = exec_p23.DIV_result;
    assign exec_result_nxt.write_hi = exec_p23.write_hi;
    assign exec_result_nxt.write_lo = exec_p23.write_lo;
    assign exec_result_nxt.HILO_result = exec_p23.HILO_result;
    assign exec_result_nxt.exec_reg1 = exec_p23.exec_reg1;
    assign exec_result_nxt.exec_reg2 = exec_p23.exec_reg2;
    //TODO more result to be done 
    assign ALU1_bypass_p1 = ALU1_result;
    assign ALU2_bypass_p1 = ALU2_result;
    assign ALU1_bypass_p2 = exec_p12.ALU1_result;
    assign ALU2_bypass_p2 = exec_p12.ALU2_result;
    assign ALU1_bypass_p3 = exec_p23.ALU1_result;
    assign ALU2_bypass_p3 = exec_p23.ALU2_result;

    ALU ALU1_ins(exec_input.ALU1_input, ALU1_result, exception_collector_nxt.ALU1_OV, exception_collector_nxt.ALU1_SYS, exception_collector_nxt.ALU1_BR);
    ALU ALU2_ins(exec_input.ALU2_input, ALU2_result, exception_collector_nxt.ALU2_OV, exception_collector_nxt.ALU2_SYS, exception_collector_nxt.ALU2_BR);
    BRU BRU_ins(exec_input.BRU_input, branch_predict_fail, BRU_link_PC, PC_not_taken, exception_collector_nxt.BRU_AdEL, exception_collector_nxt.BRU_BadVAddr, DS_EXC);
    MMU MMU_ins(exec_input.MMU_input, MMU_out, dreq, dresp, mem_halt, exception_collector_nxt.MMU_AdES, exception_collector_nxt.MMU_AdEL, exception_collector_nxt.MMU_BadVAddr, cp0_flush);
    HILO HILO_ins(exec_input.HILO_input, hi, lo, DIV_result, exec_input.exec_reg1.fu, write_hi_hl, write_lo_hl, HILO_result);
    DIV DIV_ins(clk, resetn, exec_input.DIV_input, div_halt, DIV_result);
    MLT1 MLT1_ins(exec_input.MLT_input, p0, p1);
    MLT2 MLT2_ins(exec_p12.MLT_in, p2, p3);
    MLT3 MLT3_ins(exec_p23.MLT_in, exec_p23.MLT_p, MLT_result);
    //COP0 COP0_ins(COP0_input, exception_collector_nxt.COP0_eret, COP0_result_nxt, cp0_wregsel, cp0_wdata, wfirst, wsecond, cp0_reg, cp0_flush, exception_collector_nxt.COP0_AdEL, exception_collector_nxt.COP0_BadVAddr);

    commit commit_ins(exec_result, wa5, wa6, wd5, wd6, write_en1, write_en2, hi_data, lo_data, write_hi_en, write_lo_en, exception_collector, cp0_reg_input, ext_int, cp0_reg, eret, clk, resetn, debug_wb_pc, debug_wb_rf_wen, debug_wb_rf_wnum, debug_wb_rf_wdata);

    //assign exception_collector_nxt.COP0_first = wfirst;
    //assign exception_collector_nxt.COP0_second = wsecond;

    //assign flush = branch_predict_fail || cp0_flush || eret;
    assign flush = branch_predict_fail;


    always_ff @(posedge clk) begin
        exception_collector <= '0;
        if(~resetn) begin
            fetch_PC <= '0;
            fetch_instr <= '0;
            decode_info <= '0;

        end else if(flush) begin
            fetch_PC <= '0;
            fetch_instr <= '0;
            decode_info <= '0;
            exec_result = '0;
            
            if(mem_halt) begin
            
            end else begin
                exec_input <= '0;
                
                if(cp0_flush || eret)begin
                    exec_p12 <= '0;
                    exec_p23 <= '0;
                end else begin
                    exec_p12 <= exec_p12_nxt;
                    exec_p23 <= exec_p23_nxt;
                end
            end
            
        end else if(mem_halt || div_halt) begin
            fetch_PC <= fetch_PC_nxt;
            fetch_instr <= fetch_instr_nxt;
            decode_info <= decode_info_nxt;
            exec_result <= '0;
            
        end else begin
            fetch_PC <= fetch_PC_nxt;
            fetch_instr <= fetch_instr_nxt;
            decode_info <= decode_info_nxt;

            exec_input <= exec_input_nxt;
            exec_p12 <= exec_p12_nxt;
            exec_p23 <= exec_p23_nxt;
            exec_result <= exec_result_nxt;
        end
    end

endmodule