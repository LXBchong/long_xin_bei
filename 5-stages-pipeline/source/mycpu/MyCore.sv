`include "common.svh"
`include "Myheadfile.svh"
module MyCore (
    (*mark_debug = "true"*)input logic clk, resetn,

    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp,
    output i1 uncachedD, uncachedI,
    (*mark_debug = "true"*)input i6 ext_int
);
    /****
     * TODO (Lab1) your code here :)
     ***/
// F
    i32 selpc, pred_pc;
    i1 f_vreq;
    i6 f_excCode;
    Freg freg(
        .F_pc(selpc), .F_stall,
        .f_pc, .pred_pc,
        .clk, .resetn,
        .*
    );

// D
    i32 f_pc;    
    i6 f_icode, f_acode;
    i5 f_rt, f_rs, f_rd, f_sa;
    i1 f_inDelaySlot;

    assign f_inDelaySlot = d_isJumpInstr;

    i1 d_jump, d_isJumpInstr, d_inDelaySlot;
    i32 d_jaddr;
    i32 d_pc, d_val1, d_val2, d_valt, cp0_epc;   
    i6 d_icode, d_acode, d_excCode;
    i5 d_dst, d_src1, d_src2, d_rt, d_rs;
    
    Dreg dreg(
        .d_jump, .D_excCode(f_excCode), .d_epc(cp0_epc),
        .D_pc(f_pc), .D_icode(f_icode), .D_acode(f_acode), 
        .D_rt(f_rt), .D_rs(f_rs), .D_rd(f_rd), .D_sa(f_sa),
        .w_val3, .m_val3, .e_val3,
        .w_dst, .m_dst, .e_dst,
        .pred_pc, .f_pc, .D_inDelaySlot(f_inDelaySlot),
        .clk, 
        .*
    );

//E
    i32 e_pc,e_val3;
    i6 e_icode, e_acode, e_excCode;
    i5 e_dst, e_rt, e_rs;
    i1 e_inDelaySlot;
    i32 e_valt;

    Ereg ereg(
        .E_excCode(d_excCode), .E_inDelaySlot(d_inDelaySlot),
        .E_pc(d_pc), .E_val1(d_val1),
        .E_val2(d_val2), .E_valt(d_valt),
        .E_icode(d_icode), .E_acode(d_acode),
        .E_dst(d_dst), .E_rt(d_rt), .E_rs(d_rs),
        .E_bubble, .clk,
        .*
    );

//M
    i32 m_pc, m_valo;
    i32 m_val3, m_newval3; 
    i6 m_icode, m_acode, m_excCode;
    i5 m_dst;
    i4 m_write_enable, m_write_data;
    i1 m_vreq;
    msize_t m_data_size;

    Mreg mreg(
        .M_excCode(e_excCode), .M_inDelaySlot(e_inDelaySlot),
        .M_pc(e_pc), .M_val3(e_val3), .M_icode(e_icode),
        .M_acode(e_acode), .M_dst(e_dst), .clk,
        .M_rt(e_rt), .M_valt(e_valt), 
        .M_rs(e_rs),
        .*
    );
  
//W
    i32 w_pc /* verilator public_flat_rd */;
    i32 w_val3 /* verilator public_flat_rd */;
    i6 w_acode, w_icode; 
    i5 w_dst /* verilator public_flat_rd */;
    i4 w_write_enable /* verilator public_flat_rd */;


    Wreg wreg(
        .W_pc(m_pc), .W_acode(m_acode), .W_icode(m_icode),
        .W_val3(m_val3), .W_dst(m_dst),
        .W_write_enable(m_write_enable),
        .clk,
        .*
    );

//isERET
    i1 d_isERET, ERET2pc;
    assign ERET2pc = d_isERET && i_resp;

//cp0
    i32 cp0_val, cp0_data2w, invalid_addr, excPC;
    i5 cp0_idx;
    i1 cp0_write, isBadAddr, inDelaySlot;
    i1 interrupt, exception;

    CP0 cp0(
        .*
    );

//regfile
    i32 d_regval1, d_regval2;
    i5 d_regidx1, d_regidx2;

    Regfile regfile(
        .ra1(d_regidx1), .ra2(d_regidx2), .wa3(w_dst),
        .write_enable(w_write_enable), 
        .wd3(w_val3), .rd1(d_regval1), .rd2(d_regval2),
        .clk,
        .*
    );

//hilofile
    i32 hi_cur, lo_cur;
    i32 hi_edata, lo_edata, hi_ddata, lo_ddata, hi_wdata, lo_wdata;
    i1 hi_ewrite, lo_ewrite, hi_dwrite, lo_dwrite;
    i1 hi_write, lo_write;

//mux
    always_comb begin
        if(hi_dwrite) hi_wdata = hi_ddata;
        else if(hi_ewrite) hi_wdata = hi_edata;
        else hi_wdata = '0;
    end

    always_comb begin
        if(lo_dwrite) lo_wdata = lo_ddata;
        else if(lo_ewrite) lo_wdata = lo_edata;
        else lo_wdata = '0;
    end

    always_comb begin
        hi_write = hi_ewrite | hi_dwrite;
        lo_write = lo_ewrite | lo_dwrite;
    end

    hilo hilo1(
        .hi_data(hi_wdata), .lo_data(lo_wdata),
        .hi(hi_cur), .lo(lo_cur),
        .*
    );

//PC selection
    always_comb begin
        if(exception === 1)selpc = 32'hbfc00380;
        else if(d_jump === 1)selpc = d_jaddr;
        else selpc = pred_pc;
    end

//control logic: load and use
    i1 conflict1, load, use_;   
    always_comb begin
        unique case (e_icode)
            LW:  load = 1;
            LB:  load = 1;
            LBU: load = 1;
            LH:  load = 1;
            LHU: load = 1;
            default: load = 0;
        endcase
    end
//use or not
    always_comb begin
        if(e_dst !== '0 && (e_dst === d_src1 || e_dst === d_src2))begin
            unique case (d_icode)
                J:   use_ = 0;
                JAL: use_ = 0;
                LUI: use_ = 0;
                default: use_ = 1;
            endcase
        end else begin
            use_ = 0;            
        end
    end
    assign conflict1 = load & use_;

//mul and div delay
    i1 mul_done, mul_valid, div_done, div_valid;
    i1 cal_stall;
    assign cal_stall = (mul_valid & ~mul_done) | (div_valid & ~div_done);

//bubble and stall
    i1 F_stall, D_stall, E_stall, M_stall;
    i1 D_bubble, E_bubble, M_bubble, W_bubble;
    i1 data_stall,instr_stall;

    always_comb begin
        F_stall = conflict1 | instr_stall | data_stall | cal_stall;
        D_stall = conflict1 | instr_stall | data_stall | cal_stall;  //beq or bne 
        E_stall = data_stall | cal_stall;
        M_stall = exception === 1 ? instr_stall : data_stall;

        D_bubble = instr_stall | d_isERET | exception;  
        E_bubble = conflict1 | instr_stall | exception;
        M_bubble = exception;
        W_bubble = data_stall | exception;
    end

// instruction request and reception
    typedef logic [31:0] paddr_t;
    typedef logic [31:0] vaddr_t;
    //translation for dreq

    paddr_t paddrD; // physical address
    vaddr_t vaddrD; // virtual address

    assign paddrD[27:0] = vaddrD[27:0];
    always_comb begin
        unique case (vaddrD[31:28])
            4'h8: paddrD[31:28] = 4'b0; // kseg0
            4'h9: paddrD[31:28] = 4'b1; // kseg0
            4'ha: paddrD[31:28] = 4'b0; // kseg1
            4'hb: paddrD[31:28] = 4'b1; // kseg1
            default: paddrD[31:28] = vaddrD[31:28]; // useg, ksseg, kseg3
        endcase
    end
    assign dreq.addr = paddrD;

//translation for ireq            
    paddr_t paddrI; // physical address
    vaddr_t vaddrI; // virtual address

    assign paddrI[27:0] = vaddrI[27:0];
    always_comb begin
        unique case (vaddrI[31:28])
            4'h8: paddrI[31:28] = 4'b0; // kseg0
            4'h9: paddrI[31:28] = 4'b1; // kseg0
            4'ha: paddrI[31:28] = 4'b0; // kseg1
            4'hb: paddrI[31:28] = 4'b1; // kseg1
            default: paddrI[31:28] = vaddrI[31:28]; // useg, ksseg, kseg3
        endcase
    end
    assign ireq.addr = paddrI;

    always_comb begin
        unique case (vaddrD[31:28])
            4'ha: uncachedD = 1;
            4'hb: uncachedD = 1;
            default: uncachedD = 0;
        endcase
    end

    always_comb begin
        unique case (vaddrI[31:28])
            4'ha: uncachedI = 1;
            4'hb: uncachedI = 1;
            default: uncachedI = 0;
        endcase
    end
    
//request
    always_comb begin
        vaddrI = f_pc;
        ireq.valid = f_vreq & !f_excCode[5];    
    end
    
//reception
    i32 instr;
    i1 i_resp;

    always_comb begin
        i_resp = (iresp.data_ok & iresp.addr_ok) | f_excCode[5];
        instr_stall = ~i_resp & f_vreq;

        if(i_resp)instr = iresp.data;
        else instr = '0;

        f_icode = instr[31:26];
        f_rs = instr[25:21];
        f_rt = instr[20:16];
        f_rd = instr[15:11];
        f_sa = instr[10:6];
        f_acode = instr[5:0];

    end

// data request and reception
//request
    always_comb begin
        dreq.valid = m_vreq & !exception;
        vaddrD = m_newval3;
        dreq.size = m_data_size;      //problem1: which size?
        dreq.strobe = m_write_data; //
        dreq.data = m_valo;
    end

//reception
    i32 m_data;
    i1 d_resp;
    always_comb begin
        d_resp = dresp.data_ok & dresp.addr_ok;
        if(d_resp)m_data = dresp.data;
        else m_data = '0;
        data_stall = m_vreq && ~d_resp;// && ~m_write_data[0]; //if sw then not need to save
    end

    /*
    logic _unused_ok = &{iresp, dresp};
    */
    logic _unused_ok = &{1'b0, w_pc, w_icode, w_acode,1'b0};

endmodule
