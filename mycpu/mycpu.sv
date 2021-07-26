`include "basic.svh"
`include "instr.svh"

module mycpu(
    input logic clk              ,
    input logic resetn           ,
    input logic[5:0] ext_int     ,

    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp,

    //debug
    output logic[31:0] debug_wb_pc        ,
    output logic debug_wb_rf_wen          ,
    output logic[4:0] debug_wb_rf_wnum    ,
    output logic[31:0] debug_wb_rf_wdata
);
    ibus_req_t ireq;
    ibus_resp_t iresp;
    dbus_req_t dreq;
    dbus_resp_t dresp;

    addr_t[3:0] fetch_PC, fetch_PC_nxt;
    instr_t[3:0] fetch_instr, fetch_instr_nxt;
    decode_t[3:0] decode_info, decode_info_nxt;
    logic[3:0] decode_en;

    decode_t[1:0] issue_instr;
    logic[1:0] issue_cnt;
    logic queue_full;

    logic mem_halt, flush;

    regid_t ra1, ra2, ra3, ra4, wa5, wa6;
    word_t rd1, rd2, rd3, rd4, wd5, wd6;
    logic write_en1, write_en2;

    ALU_input_t ALU1_input, ALU2_input, ALU1_input_nxt, ALU2_input_nxt;
    BRU_input_t BRU_input, BRU_input_nxt;
    MMU_input_t MMU_input, MMU_input_nxt;
    exec_reg_t exec_reg1, exec_reg2, exec_reg1_nxt, exec_reg2_nxt;
    exec_reg_t exec_reg1_p2, exec_reg2_p2, exec_reg1_p2_nxt, exec_reg2_p2_nxt;
    word_t ALU1_result, ALU2_result, ALU1_result_nxt, ALU2_result_nxt, MMU_out, MMU_out_nxt;
    logic branch_predict_fail;
    addr_t BRU_link_PC, BRU_link_PC_nxt, PC_not_taken;

    //TODO: doesn't have cache yet
    fetch fetch_ins(clk, resetn, fetch_PC_nxt, fetch_instr_nxt, ireq, iresp, PC_not_taken, branch_predict_fail);

    decode decode_ins1(fetch_PC[0], fetch_instr[0], decode_info_nxt[0]);
    decode decode_ins2(fetch_PC[1], fetch_instr[1], decode_info_nxt[1]);
    decode decode_ins3(fetch_PC[2], fetch_instr[2], decode_info_nxt[2]);
    decode decode_ins4(fetch_PC[3], fetch_instr[3], decode_info_nxt[3]);

    assign decode_en = 4'b1111;
    queue issue_queue_ins(clk, resetn, flush, decode_info, decode_en, issue_instr, issue_cnt, queue_full);
    issue issue_ins(clk, resetn, issue_instr, ALU1_input_nxt, ALU2_input_nxt, BRU_input_nxt, MMU_input_nxt, exec_reg1_nxt, exec_reg2_nxt, issue_cnt, ra1, ra2, ra3, ra4, rd1, rd2, rd3, rd4);

    regfile regfile_ins(.*);

    ALU ALU1_ins(ALU1_input, ALU1_result_nxt);
    ALU ALU2_ins(ALU2_input, ALU2_result_nxt);
    BRU BRU_ins(BRU_input, branch_predict_fail, BRU_link_PC_nxt, PC_not_taken);
    MMU MMU_ins(MMU_input, MMU_out_nxt, dreq, dresp, mem_halt);

    commit commit_ins(exec_reg1_p2, exec_reg2_p2, ALU1_result, ALU2_result, MMU_out, BRU_link_PC, wa5, wa6, wd5, wd6, .*);

    assign exec_reg1_p2_nxt = exec_reg1;
    assign exec_reg2_p2_nxt = exec_reg2;

    assign flush = branch_predict_fail;

    always_ff @(posedge clk) begin
        if(resetn) begin
            fetch_PC <= '0;
            fetch_instr <= '0;
            decode_info <= '0;

        end else if(flush) begin
            fetch_PC <= '0;
            fetch_instr <= '0;
            decode_info <= '0;

        end else if(mem_halt) begin
            fetch_PC <= fetch_PC_nxt;
            fetch_instr <= fetch_instr_nxt;
            decode_info <= decode_info_nxt;
            
        end begin
            fetch_PC <= fetch_PC_nxt;
            fetch_instr <= fetch_instr_nxt;
            decode_info <= decode_info_nxt;

            ALU1_input <= ALU1_input_nxt;
            ALU2_input <= ALU2_input_nxt;
            MMU_input <= MMU_input_nxt;
            BRU_input <= BRU_input_nxt;
            exec_reg1 <= exec_reg1_nxt;
            exec_reg2 <= exec_reg2_nxt;
            exec_reg1_p2 <= exec_reg1_p2_nxt;
            exec_reg2_p2 <= exec_reg2_p2_nxt;
            ALU1_result <= ALU1_result_nxt;
            ALU2_result <= ALU2_result_nxt;
            MMU_out <= MMU_out_nxt;
            BRU_link_PC <= BRU_link_PC_nxt;

        end
    end

endmodule