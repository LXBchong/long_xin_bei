`include "def.svh"


module D_LUTRAM #(

    localparam int DATA_WIDTH = 32 * 4,
    localparam int ADDR_WIDTH = Dcache_index_bits,
    localparam int BYTE_WRITE = 1,
    localparam int BYTE_WIDTH = 8,


    localparam int NUM_DATA  = 2 ** ADDR_WIDTH,
    localparam int BYTES_PER_DATA = DATA_WIDTH / BYTE_WIDTH ,
    localparam int NUM_BITS   = NUM_DATA * DATA_WIDTH 
) (
    input logic clk,resetn,

    input logic[ADDR_WIDTH-1:0] addr,
    input logic[BYTES_PER_DATA-1:0] strobe,
    input logic[DATA_WIDTH-1:0] wdata,

    output logic[DATA_WIDTH-1:0] rdata
);

// xpm_memory_spram: Single Port RAM
// Xilinx Parameterized Macro, version 2019.2
xpm_memory_spram #(
    .ADDR_WIDTH_A(ADDR_WIDTH),
    .AUTO_SLEEP_TIME(0),
    .BYTE_WRITE_WIDTH_A(BYTE_WIDTH),
    .CASCADE_HEIGHT(0),
    .ECC_MODE("no_ecc"),
    .MEMORY_INIT_FILE("none"),
    .MEMORY_INIT_PARAM("0"),
    .MEMORY_OPTIMIZATION("true"),
    .MEMORY_PRIMITIVE("distributed"),
    .MEMORY_SIZE(NUM_BITS),
    .MESSAGE_CONTROL(0),
    .READ_DATA_WIDTH_A(DATA_WIDTH),
    .READ_LATENCY_A(0),
    .READ_RESET_VALUE_A("0"),
    .RST_MODE_A("SYNC"),
    .SIM_ASSERT_CHK(1),
    .USE_MEM_INIT(0),
    .WAKEUP_TIME("disable_sleep"),
    .WRITE_DATA_WIDTH_A(DATA_WIDTH),
    .WRITE_MODE_A("read_first")
) xpm_memory_spram_inst (
    .clka(clk), .ena(resetn),
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

// lutram lut_inst(.addr(addr),.rdata(data),.*);

