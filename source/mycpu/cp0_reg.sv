`include "common.svh"
`include "instr.svh"

module cp0_reg(
    input logic clk, resetn,
    input cp0_reg_input_t cp0_reg_input,
    input logic[7:0] cp0_wregsel,
    input word_t cp0_wdata, cp0_wpc,
    input logic wfirst, wsecond,
    output cp0_regfile_t cp0_reg,
    input logic eret,
    output logic cp0_flush,
    output addr_t wPC
);  
    cp0_regfile_t cp0_reg_nxt;
    logic ticker, BD, en;
    addr_t EPC, BadVAddr, wPC_nxt;
    ecode_t ExeCode;
    word_t data, check;
    logic[7:0] regsel;

    assign BD = cp0_reg_input.BD;
    assign EPC = cp0_reg_input.EPC;
    assign BadVAddr = cp0_reg_input.BadVAddr;
    assign ExeCode = cp0_reg_input.ExeCode;
    assign en = cp0_reg_input.exception_en;
    assign regsel = cp0_wregsel;
    assign data = cp0_wdata;

    always_comb begin
        cp0_reg_nxt = cp0_reg;
        cp0_flush = 0;
        check = '0;
        wPC_nxt = wPC;
        
        if(wsecond) begin
            wPC_nxt = cp0_wpc;
            unique case(regsel)
                RS_COUNT: cp0_reg_nxt.Count = data;
    
                RS_COMPARE: cp0_reg_nxt.Compare = data;
    
                RS_EPC: cp0_reg_nxt.EPC = data;
    
                RS_CAUSE: cp0_reg_nxt.Cause = (data & CP0_CAUSE_MASK) | (cp0_reg.Cause & ~CP0_CAUSE_MASK);
                //RS_CAUSE: cp0_reg_nxt.Cause = data & CP0_CAUSE_MASK;
    
                RS_STATUS: cp0_reg_nxt.Status = (data & CP0_STATUS_MASK) | (cp0_reg.Status & ~CP0_STATUS_MASK);
                //RS_STATUS: cp0_reg_nxt.Status = data & CP0_STATUS_MASK;
    
                default:begin end
            endcase
        end
        
        if(~cp0_reg.Status.EXL && en)begin
            cp0_flush = 1;
            cp0_reg_nxt.EPC = EPC;
            cp0_reg_nxt.Cause.BD = BD;
            cp0_reg_nxt.Cause.ExcCode = ExeCode;
            cp0_reg_nxt.Status.EXL = 1;
            if(ExeCode == EX_ADEL || ExeCode == EX_ADES)
                cp0_reg_nxt.BadVAddr = BadVAddr;
        end

        cp0_reg_nxt.Cause.TI = cp0_reg.Count == cp0_reg.Compare && cp0_reg.Compare != 0;
        cp0_reg_nxt.Count = ticker ? cp0_reg.Count + 32'd1 : cp0_reg.Count; 
        if(eret) cp0_reg_nxt.Status.EXL = 0;

        if(wfirst) begin
            wPC_nxt = cp0_wpc;
            unique case(regsel)
                RS_COUNT: cp0_reg_nxt.Count = data;
    
                RS_COMPARE: cp0_reg_nxt.Compare = data;
    
                RS_EPC: cp0_reg_nxt.EPC = data;
    
                RS_CAUSE: cp0_reg_nxt.Cause = (data & CP0_CAUSE_MASK) | (cp0_reg.Cause & ~CP0_CAUSE_MASK);
                //RS_CAUSE: cp0_reg_nxt.Cause = data & CP0_CAUSE_MASK;
    
                RS_STATUS: cp0_reg_nxt.Status = (data & CP0_STATUS_MASK) | (cp0_reg.Status & ~CP0_STATUS_MASK);
                //RS_STATUS: cp0_reg_nxt.Status = data & CP0_STATUS_MASK;
    
                default:begin end
            endcase
        end
    end

    // write: sequential logic
    always_ff @(posedge clk) begin
		if (~resetn) begin
			cp0_reg <= '0;
            ticker <= 0;
            wPC <= '0;
		end else begin
			cp0_reg <= cp0_reg_nxt;
            ticker <= ~ticker;
            wPC <= wPC_nxt;
		end
    end

    

endmodule