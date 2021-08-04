`include "common.svh"
`include "Myheadfile.svh"
module Mreg(
    input i32 M_pc, M_val3, M_valt, 
    input i6 M_icode, M_acode, M_excCode,
    input i5 M_dst, M_rt, M_rs,
    input i1 M_stall, M_bubble, clk, resetn, M_inDelaySlot,

    output i32 m_pc, m_val3, m_valo, m_newval3,
    output i6 m_icode, m_acode, m_excCode,
    output i5 m_dst,
    output i4 m_write_enable, m_write_data,
    output i1 m_vreq, //need data
    output msize_t m_data_size,
    
    input i32 m_data,
    input i1 interrupt,
    output i1 exception, isBadAddr, inDelaySlot,

    output i32 invalid_addr, excPC
);
    i32 m_valt;
    i6 m_tCode;
    i5 m_rs, m_rt;

    always_ff @(posedge clk) begin
        if(~resetn | exception) begin
            m_pc <= 0;
            m_icode <= 0;
            m_acode <= 0;
            m_dst <= 0;
            m_newval3 <= 0;
            m_valt <= '0;
            m_rt <= 0;
            m_rs <= '0;
            m_tCode <= '0;
            inDelaySlot <= '0;
        end else if(M_stall)begin

        end else begin
            m_pc <= M_pc;
            m_icode <= M_icode;
            m_acode <= M_acode;
            m_dst <= M_dst;
            m_newval3 <= M_val3;
            m_valt <= M_valt;
            m_rt <= M_rt;
            m_rs <= M_rs;
            m_tCode <= M_excCode;
            inDelaySlot <= M_inDelaySlot;
        end
    end

    assign isBadAddr = (m_excCode[4:0] === 5'h04) | (m_excCode[4:0] === 5'h05);
    assign excPC = m_pc;

//alignment
    i1 isAddrD_align;
    always_comb begin
        unique case (m_icode)
            SW:  isAddrD_align = m_newval3[1:0] === 2'b00;
            SH:  isAddrD_align = m_newval3[0] === 1'b0;
            LW:  isAddrD_align = m_newval3[1:0] === 2'b00;
            LH:  isAddrD_align = m_newval3[0] === 1'b0;
            LHU: isAddrD_align = m_newval3[0] === 1'b0;
            default: isAddrD_align = 1;
        endcase
    end

    i1 isStore;
    always_comb begin
        unique case (m_icode)
            SW: isStore = 1;
            SH: isStore = 1;
            SB: isStore = 1;
            default isStore = 0;
        endcase
    end

//is break or syscall
    i1 isBreak, isSyscall;
    assign isBreak = (m_icode === SPE) && (m_acode === BREAK);
    assign isSyscall = (m_icode === SPE) && (m_acode === SYSCALL);
    assign exception = m_excCode[5] === 1 | interrupt === 1;

    always_comb begin
        if(interrupt)begin
            m_excCode = 6'b100000;
        end else if(m_tCode[5])begin
            invalid_addr = m_pc;  
            m_excCode = m_tCode;
        end else if(isBreak | isSyscall) begin
            m_excCode = isBreak ? 6'b101001 : 6'b101000;
        end else if(!isAddrD_align) begin
            invalid_addr = m_newval3;
            m_excCode = isStore ? 6'b100101 : 6'b100100; 
        end else m_excCode = 6'b000000;
    end

    always_comb begin
        if(m_excCode[5]) m_vreq = 0;
        else begin
            unique case (m_icode)
                SW:  m_vreq = 1;
                LW:  m_vreq = 1;
                LB:  m_vreq = 1;
                LBU: m_vreq = 1;
                LH:  m_vreq = 1;
                LHU: m_vreq = 1;
                SB:  m_vreq = 1;
                SH:  m_vreq = 1;
                default: m_vreq = 0;
            endcase
        end
    end

//Save data
    always_comb begin
        unique case (m_icode)
            SB: m_valo = {4{m_valt[7:0]}};
            SH: m_valo = {2{m_valt[15:0]}};
            default: m_valo = m_valt;
        endcase
    end
//val3 decision
    always_comb begin
        unique case (m_icode)
            LW:  m_val3 = m_data;
            LB: begin 
                unique case (m_newval3[1:0])
                    2'b00: m_val3 = {{24{m_data[7]}}, m_data[7:0]};
                    2'b01: m_val3 = {{24{m_data[15]}}, m_data[15:8]};
                    2'b10: m_val3 = {{24{m_data[23]}}, m_data[23:16]};
                    2'b11: m_val3 = {{24{m_data[31]}}, m_data[31:24]};
                    default: m_val3 = '0;
                endcase
            end
            LBU:begin
                unique case (m_newval3[1:0])
                    2'b00: m_val3 = {{24{1'b0}}, m_data[7:0]};
                    2'b01: m_val3 = {{24{1'b0}}, m_data[15:8]};
                    2'b10: m_val3 = {{24{1'b0}}, m_data[23:16]};
                    2'b11: m_val3 = {{24{1'b0}}, m_data[31:24]};
                    default: m_val3 = '0;
                endcase
            end
            LH: begin
                if(m_newval3[1])m_val3 = {{16{m_data[31]}}, m_data[31:16]};
                else m_val3 = {{16{m_data[15]}}, m_data[15:0]};
            end 
            LHU: begin
                if(m_newval3[1])m_val3 = {{16{1'b0}}, m_data[31:16]};
                else m_val3 = {{16{1'b0}}, m_data[15:0]};
            end 
            default: m_val3 = m_newval3;
        endcase
    end

//transfer the en signal
    always_comb begin 
        if(m_pc === 32'h0000_0000) m_write_enable = '0; //ensure the bubble come out all 0 results.
        else begin
            unique case (m_icode)
                ADDI:  m_write_enable = 4'b1111;
                ADDIU: m_write_enable = 4'b1111;
                ANDI:  m_write_enable = 4'b1111;
                JAL:   m_write_enable = 4'b1111;
                LUI:   m_write_enable = 4'b1111;
                LW:    m_write_enable = 4'b1111;
                ORI:   m_write_enable = 4'b1111;
                SLTI:  m_write_enable = 4'b1111;
                SLTIU: m_write_enable = 4'b1111;
                XORI:  m_write_enable = 4'b1111;
                SPE: begin
                    unique case (m_acode)                        
                        JR:   m_write_enable = 4'b0000;
                        DIV:  m_write_enable = 4'b0000;
                        DIVU: m_write_enable = 4'b0000;
                        MTHI: m_write_enable = 4'b0000;
                        MTLO: m_write_enable = 4'b0000;
                        MULT: m_write_enable = 4'b0000;
                        MULTU: m_write_enable = 4'b0000;
                        BREAK: m_write_enable = 4'b0000;
                        SYSCALL: m_write_enable = 4'b0000;
                        default: m_write_enable = 4'b1111;
                    endcase
                end

                SPE2: m_write_enable = (m_acode === MUL) ? 4'b1111 : 4'b0000;
                REGIMM: begin
                    unique case (m_rt)
                        BGEZAL: m_write_enable = 4'b1111;
                        BLTZAL: m_write_enable = 4'b1111;
                        default: m_write_enable = 4'b0000;
                    endcase
                end
                LB:   m_write_enable = 4'b1111;
                LBU:  m_write_enable = 4'b1111;
                LH:   m_write_enable = 4'b1111;
                LHU:  m_write_enable = 4'b1111;

                COP0: begin
                    unique case (m_rs)
                        MFC0:  m_write_enable = 4'b1111;
                        default: m_write_enable = 4'b0000;
                    endcase
                end
                default: m_write_enable = 4'b0000;
            endcase
        end
    end

//request for Data memory
    always_comb begin
        unique case (m_icode)
            SW:  m_write_data = 4'b1111;
            SB: begin
                unique case (m_newval3[1:0])
                    2'b00: m_write_data = 4'b0001;
                    2'b01: m_write_data = 4'b0010;
                    2'b10: m_write_data = 4'b0100;
                    2'b11: m_write_data = 4'b1000;
                endcase
            end 
            SH: begin 
                if(m_newval3[1])m_write_data = 4'b1100;
                else m_write_data = 4'b0011;
            end
            default: m_write_data = 4'b0000;
        endcase
    end

    always_comb begin
        unique case (m_icode)
            SW:   m_data_size = MSIZE4;
            SB:   m_data_size = MSIZE1;
            SH:   m_data_size = MSIZE2;

            LW:   m_data_size = MSIZE4;
            LB:   m_data_size = MSIZE1;
            LBU:  m_data_size = MSIZE1;
            LH:   m_data_size = MSIZE2;
            LHU:  m_data_size = MSIZE2;
            default: m_data_size = MSIZE4;
        endcase
    end
endmodule