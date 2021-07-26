`include "common.svh"
`include "instr.svh"

module COP0 (
    input COP0_input_t in,
    output logic COP0_eret,
    output word_t COP0_result,
    output logic[7:0] write_regsel,
    output word_t write_data,
    output logic wfirst, wsecond,
    input cp0_regfile_t cp0_reg,
    input logic cp0_flush,
    output logic COP0_AdEL,
    output addr_t COP0_BadVAddr
);
    //eret to error address
    assign COP0_AdEL = in.eret && cp0_reg.EPC[1:0] != 2'b00;
    assign COP0_BadVAddr = COP0_AdEL ? cp0_reg.EPC : '0;
    assign COP0_eret = in.eret;
    assign write_regsel = in.mt && ~cp0_flush ? in.regsel : '0;
    assign write_data = in.write_data;
    
    assign wfirst = in.first;
    assign wsecond = in.second;

    always_comb begin
        COP0_result = '0;
        if(in.mf) begin
            unique case(in.regsel)
                RS_BADVADDR:
                    COP0_result = cp0_reg.BadVAddr;
                RS_COUNT:
                    COP0_result = cp0_reg.Count;
                RS_COMPARE:
                    COP0_result = cp0_reg.Compare;
                RS_STATUS:
                    COP0_result = cp0_reg.Status;
                RS_CAUSE:
                    COP0_result = cp0_reg.Cause;
                RS_EPC:
                    COP0_result = cp0_reg.EPC;
                default: begin end
            endcase
        end
    end

endmodule