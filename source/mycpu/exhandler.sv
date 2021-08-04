`include "common.svh"
`include "instr.svh"

module exhandler(
    input exec_reg_t exec_reg1, exec_reg2,
    input exception_collector_t exception_collector,
    input cp0_regfile_t cp0_reg,
    output cp0_reg_input_t cp0_reg_input,
    output logic exception1_en, exception2_en, eret,
    input logic[5:0] ext_int
);
    logic BD;
    logic[7:0] interrupt_info;
    addr_t EPC, BadVAddr;
    ecode_t ExeCode;
    assign eret = exception_collector.COP0_eret && ~exception_collector.COP0_AdEL;
    assign interrupt_info = ({ext_int, 2'b00} | cp0_reg.Cause.IP | {cp0_reg.Cause.TI, 7'b0}) & cp0_reg.Status.IM;
    
    always_comb begin
        exception1_en = 0;
        exception2_en = 0;
        BD = 0;
        EPC = '0;
        BadVAddr = '0;
        ExeCode = EX_NONE;

        if(interrupt_info && exec_reg1.en && ~cp0_reg.Status.EXL) begin
            exception1_en = 1;
            EPC = exec_reg1.PC;
            ExeCode = EX_INT;
        end else if(exec_reg1.en && exception_collector.BRU_AdEL
            && (~exception_collector.ALU2_BR && ~exception_collector.ALU2_SYS && ~exception_collector.ALU2_OV
            && ~exception_collector.COP0_AdEL && ~exception_collector.AGU_AdEL && ~exception_collector.AGU_AdES
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
        end else if(exec_reg1.en && exec_reg1.fu == AGU && exception_collector.AGU_AdEL) begin
            exception1_en = 1;
            EPC = exec_reg1.PC;
            ExeCode = EX_ADEL;
            BadVAddr = exception_collector.AGU_BadVAddr;
        end else if(exec_reg1.en &&  exec_reg1.fu == AGU && exception_collector.AGU_AdES) begin
            exception1_en = 1;
            EPC = exec_reg1.PC;
            ExeCode = EX_ADES;
            BadVAddr = exception_collector.AGU_BadVAddr;
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
        end else if(exec_reg2.en && exception_collector.AGU_AdEL) begin
            exception2_en = 1;
            EPC = exec_reg2.PC;
            ExeCode = EX_ADEL;
            BadVAddr = exception_collector.AGU_BadVAddr;
            if(exec_reg1.fu == BRU)begin
                EPC = exec_reg2.PC - 32'd4;
                BD = 1;
            end
        end else if(exec_reg2.en && exception_collector.AGU_AdES) begin
            exception2_en = 1;
            EPC = exec_reg2.PC;
            ExeCode = EX_ADES;
            BadVAddr = exception_collector.AGU_BadVAddr;
            if(exec_reg1.fu == BRU)begin
                EPC = exec_reg2.PC - 32'd4;
                BD = 1;
            end
        end
    end

    assign cp0_reg_input.exception_en = exception1_en | exception2_en;
    assign cp0_reg_input.BD = BD;
    assign cp0_reg_input.EPC = EPC;
    assign cp0_reg_input.BadVAddr = BadVAddr;
    assign cp0_reg_input.ExeCode = ExeCode;

endmodule