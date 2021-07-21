`include "def.svh"


module D_data #(
    parameter int NUM_BYTES = 64,  // 16, 32 or 64

    localparam int BYTE_WIDTH = 8,
    localparam int WORD_WIDTH = 32,
    localparam bit BYTE_WRITE = 1,

    localparam int NUM_WORDS  = NUM_BYTES * BYTE_WIDTH / WORD_WIDTH,
    localparam int ADDR_WIDTH = 4,
    localparam int LANE_WIDTH = WORD_WIDTH, 
) (
    input logic clk,en,

    input logic[ADDR_WIDTH-1:0] addr,
    input logic strobe,
    input word_t wdata,
     
    output word_t rdata
);

// xpm_memory_spram: Single Port RAM
// Xilinx Parameterized Macro, version 2019.2
xpm_memory_spram #(
    .ADDR_WIDTH_A(ADDR_WIDTH),
    .AUTO_SLEEP_TIME(0),
    .BYTE_WRITE_WIDTH_A(LANE_WIDTH),
    .CASCADE_HEIGHT(0),
    .ECC_MODE("no_ecc"),
    .MEMORY_INIT_FILE("none"),
    .MEMORY_INIT_PARAM("0"),
    .MEMORY_OPTIMIZATION("true"),
    .MEMORY_PRIMITIVE("distributed"),
    .MEMORY_SIZE(NUM_BITS),
    .MESSAGE_CONTROL(0),
    .READ_DATA_WIDTH_A(WORD_WIDTH),
    .READ_LATENCY_A(0),
    .READ_RESET_VALUE_A("0"),
    .RST_MODE_A("SYNC"),
    .SIM_ASSERT_CHK(1),
    .USE_MEM_INIT(0),
    .WAKEUP_TIME("disable_sleep"),
    .WRITE_DATA_WIDTH_A(WORD_WIDTH),
    .WRITE_MODE_A("read_first")
) xpm_memory_spram_inst (
    .clka(clk), .ena(en),
    .addra(addr),
    .wea(strobe),
    .dina(wdata),
    .douta(rdata),

    .regcea(1),
    .rsta(0),
    .sleep(0),
    .injectdbiterra(0),
    .injectsbiterra(0)
);
// End of xpm_memory_spram_inst instantiation


endmodule