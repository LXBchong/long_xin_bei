`include "common.svh"
`include "instr.svh"

module ICache_se(
    input logic clk, resetn,

    input ibus_req_t ireq,
    output ibus_resp_t iresp,

    input cbus_resp_t icresp,
    output cbus_req_t icreq
);

    parameter int INSTR_SIZE = `ICache_instr_num;

    typedef word_t[INSTR_SIZE-1:0] cacheline_t;

    logic last_flag, last_flag_nxt, tag, tag_nxt;

    ibus_resp_t iresp_nxt;
    cbus_req_t icreq_nxt;
    cacheline_t the_missed_cacheline, the_missed_cacheline_nxt;

    addr_t paddr, vaddr;
    assign vaddr = ireq.addr;
    assign paddr[27:0] = vaddr[27:0];

    always_comb begin
        unique case (vaddr[31:28])
            4'h8: paddr[31:28] = 4'b0;
            4'h9: paddr[31:28] = 4'b1;
            4'ha: paddr[31:28] = 4'b0;
            4'hb: paddr[31:28] = 4'b1;
            default : paddr[31:28] = vaddr[31:28];
        endcase
    end

    assign last_flag_nxt = icresp.last;

    always_comb begin
        icreq_nxt.valid = ireq.valid;
        icreq_nxt.is_write = 0;
        icreq_nxt.size = MSIZE4;
        icreq_nxt.strobe = 4'b0;
        icreq_nxt.data = '0;
        icreq_nxt.addr = (paddr[2] == 1) ? {paddr[31:3], 3'b0} : paddr; //8bytes aligned
        icreq_nxt.len = MLEN2;
        iresp_nxt = iresp;
        tag_nxt = tag;
        the_missed_cacheline_nxt = the_missed_cacheline;
        if(last_flag) begin
            icreq_nxt = '0;
            iresp_nxt = '0;
            the_missed_cacheline_nxt = '0;
        end if(ireq.valid && icresp.ready) begin
            the_missed_cacheline_nxt[tag] = icresp.data;
            tag_nxt = tag + 1;
            if(icresp.last) begin
                iresp_nxt.addr_ok = 1;
                iresp_nxt.data_ok = 1;
                iresp_nxt.data = the_missed_cacheline_nxt;
                for(int j = 0; j < INSTR_SIZE; j++) begin//predecode
                    if(iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000100 || //beq
                        iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000101 || //bne
                        iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000110 || //blez
                        iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000111 || //bgtz
                        iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000010 || //j
                        iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000000 && iresp_nxt.data[j[INSTR_SIZE-1:0]][5:0]   == 6'b001001 || //jalr
                        iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000001 && iresp_nxt.data[j[INSTR_SIZE-1:0]][20:16] == 5'b00001  || //bgez
                        iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000001 && iresp_nxt.data[j[INSTR_SIZE-1:0]][20:16] == 5'b10001  || //bgezal
                        iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000001 && iresp_nxt.data[j[INSTR_SIZE-1:0]][20:16] == 5'b00000  || //bltz
                        iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000001 && iresp_nxt.data[j[INSTR_SIZE-1:0]][20:16] == 5'b10010     //bltzal
                       ) begin //is_branch
                        iresp_nxt.predecode[j[INSTR_SIZE-1:0]] = is_branch;
                    end else if (iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000000 &&
                                iresp_nxt.data[j[INSTR_SIZE-1:0]][25:21] == 5'b11111  &&
                                iresp_nxt.data[j[INSTR_SIZE-1:0]][5:0]   == 6'b001000
                                 ) begin //is_ret jr ra
                        iresp_nxt.predecode[j[INSTR_SIZE-1:0]] = is_ret;
                    end else if (iresp_nxt.data[j[INSTR_SIZE-1:0]][31:26] == 6'b000011) begin //is_call jal
                                 iresp_nxt.predecode[j[INSTR_SIZE-1:0]] = is_call;
                    end else begin //normal
                        iresp_nxt.predecode[j[INSTR_SIZE-1:0]] = normal;
                    end
                end
            end
        end else begin
            
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin
            iresp <= '0;
            icreq <= '0;
            the_missed_cacheline <= '0;
            last_flag <= 0;
            tag <= '0;
        end else begin
            iresp <= iresp_nxt;
            icreq <= icreq_nxt;
            the_missed_cacheline <= the_missed_cacheline_nxt;
            last_flag <= last_flag_nxt;
            tag <= tag_nxt;
        end
    end;

endmodule