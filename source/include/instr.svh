`ifndef __INSTR_SVH__
`define __INSTR_SVH__

`include "common.svh"

typedef logic[4:0]  shamt_t;
typedef logic[15:0] imm_t;
typedef logic[25:0] long_imm_t;

typedef enum i5 {
    AR_NONE ,AR_ADDU, AR_SUBU, AR_SLL, AR_SRA, AR_SRL,
    AR_SLT, AR_SLTU, AR_XOR, AR_AND, AR_NOT, AR_OR, AR_NOR,
    AR_LU, AR_SYS, AR_BR, AR_ADD, AR_SUB
} arith_t;

typedef enum i3{
    CMP_NONE ,CMP_EQL, CMP_GE, CMP_LE, CMP_NE,
    CMP_G, CMP_L, CMP_J
} compare_t;

//branch prediction defs
typedef struct packed {
    logic is_ret;
} BIT_t;

typedef struct packed {
    addr_t PC;
    logic[7:0] counter;
} RAS_t;

typedef struct packed {
    logic branch_taken;
    addr_t predict_PC;
} branch_predict_t;

typedef logic[1:0] PHT_t;
//3-strong jump, 2-weak jump, 1-weak nojump, 0-strong nojump

typedef struct packed {
    logic branch_in_exec;
    logic branch_result;
    addr_t branch_ins_PC;
    addr_t jump_PC; 
    logic is_ret;
    logic is_call;
} BRU_BP_bypass_t;

typedef struct packed {
    logic valid;
    addr_t PC;    
    logic second_is_branch;
    logic[1:0] is_ret;
} fetch2_BP_bypass_t;

typedef enum i6 {
    OP_RTYPE = 6'b000000,
    OP_BTYPE = 6'b000001,
    OP_J     = 6'b000010,
    OP_JAL   = 6'b000011,
    OP_BEQ   = 6'b000100,
    OP_BNE   = 6'b000101,
    OP_BLEZ  = 6'b000110,
    OP_BGTZ  = 6'b000111,
    OP_ADDI  = 6'b001000,
    OP_ADDIU = 6'b001001,
    OP_SLTI  = 6'b001010,
    OP_SLTIU = 6'b001011,
    OP_ANDI  = 6'b001100,
    OP_ORI   = 6'b001101,
    OP_XORI  = 6'b001110,
    OP_LUI   = 6'b001111,
    OP_SP2   = 6'b011100,
    OP_COP0  = 6'b010000,
    OP_LB    = 6'b100000,
    OP_LH    = 6'b100001,
    OP_LW    = 6'b100011,
    OP_LBU   = 6'b100100,
    OP_LHU   = 6'b100101,
    OP_SB    = 6'b101000,
    OP_SH    = 6'b101001,
    OP_SW    = 6'b101011
} opcode_t;

typedef enum i6 {
    FN_SLL     = 6'b000000,
    FN_SRL     = 6'b000010,
    FN_SRA     = 6'b000011,
    FN_SRLV    = 6'b000110,
    FN_SRAV    = 6'b000111,
    FN_SLLV    = 6'b000100,
    FN_JR      = 6'b001000,
    FN_JALR    = 6'b001001,
    FN_SYSCALL = 6'b001100,
    FN_BREAK   = 6'b001101,
    FN_MFHI    = 6'b010000,
    FN_MTHI    = 6'b010001,
    FN_MFLO    = 6'b010010,
    FN_MTLO    = 6'b010011,
    FN_MULT    = 6'b011000,
    FN_MULTU   = 6'b011001,
    FN_DIV     = 6'b011010,
    FN_DIVU    = 6'b011011,
    FN_ADD     = 6'b100000,
    FN_ADDU    = 6'b100001,
    FN_SUB     = 6'b100010,
    FN_SUBU    = 6'b100011,
    FN_AND     = 6'b100100,
    FN_OR      = 6'b100101,
    FN_XOR     = 6'b100110,
    FN_NOR     = 6'b100111,
    FN_SLT     = 6'b101010,
    FN_SLTU    = 6'b101011
} funct_t;

typedef enum i5 {
    BR_BLTZ   = 5'b00000,
    BR_BGEZ   = 5'b00001,
    BR_BLTZAL = 5'b10000,
    BR_BGEZAL = 5'b10001
} btype_t;

typedef enum i5 {
    CFN_MF = 5'b00000,
    CFN_MT = 5'b00100
} cp0_fn_t;

typedef enum i6 {
    COFN_ERET = 6'b011000
} cp0_cofn_t;

typedef enum i5 {
    R0, AT, V0, V1, A0, A1, A2, A3,
    T0, T1, T2, T3, T4, T5, T6, T7,
    S0, S1, S2, S3, S4, S5, S6, S7,
    T8, T9, K0, K1, GP, SP, FP, RA
} regid_t;

typedef struct packed {
    regid_t  rs;
    regid_t  rt;
    regid_t  rd;
    shamt_t  shamt;
    funct_t  funct;
} rtype_instr_t;

typedef struct packed {
    regid_t  rs;
    regid_t  rt;
    imm_t    imm;
} itype_instr_t;

typedef struct packed {
    cp0_fn_t funct;
    regid_t  rt;
    regid_t  rd;
    i8       _unused_1;
    i3       sel;
} cop0_instr_t;

typedef struct packed {
    i1         co;      
    i19        _unused_1;
    cp0_cofn_t funct;
} cop0_co_instr_t;

typedef struct packed {
    opcode_t opcode;
    union packed {
        rtype_instr_t   rtype;
        itype_instr_t   itype;
        cop0_instr_t    cop0;
        cop0_co_instr_t cop0_co;
        long_imm_t      index;
    } payload;
} instr_t;

typedef enum i3{
    RTYPE, ITYPE, COP0, COP0_CO, INDEX
}instr_type_t;

parameter instr_t INSTR_NOP = 32'b0;

typedef enum i3{
    U_NONE, U_BRANCH, U_MEMORY, U_ALU, 
    U_HILO, U_MLT, U_DIV, U_COP0
} unit_t;

typedef struct packed {
    addr_t cur_PC;
    branch_predict_t bp_info;
    logic[1:0] PC_valid;
    ibus_resp_t iresp;
    logic is_DS;
} fetch2_input_t;

typedef struct packed {
    logic[1:0] PC_valid;
    branch_predict_t bp_info;
    addr_t[1:0] PC;
    instr_t[1:0] instr;
    logic[1:0] is_ret;
    logic[1:0] is_call;
} decode_input_t;

typedef struct packed {
    logic en;
    logic first;
    addr_t PC;
    instr_t instr;
} decoder_input_t;

typedef struct packed {
    addr_t PC;
    unit_t unit;
    instr_type_t instr_type;
    logic RI;
    logic first;
    branch_predict_t bp_info;
    //consider form regC <- regA op regB
    //      or form regA cmp regB
    //reg info
    regid_t regA;
    regid_t regB;
    regid_t regC;
    logic read_en_A;
    logic read_en_B;
    logic write_en_C;
    word_t imm;
    //alu info
    arith_t operator;
    shamt_t shamt;
    //bru info 
    compare_t cmp;
    word_t jump_PC;
    logic is_ret;
    logic is_call;
    //mem info
    logic mem_read;
    logic mem_write;
    logic unsign_en;
    msize_t msize;
    //mlt / div info
    logic hilo_unsign;
    //hilo info
    logic write_hi;
    logic write_lo;
    logic read_lo;
    logic read_hi;
    //cp0 info
    logic mf;
    logic mt;
    logic[7:0] regsel;
    logic eret;
} decode_t;

typedef enum i4{
    None, ALU1, BRU, AGU, ALU2, HILO, MLT, DIV, CP0
}function_unit_t;

typedef struct packed{
    logic pending;
    function_unit_t fu;
    logic[1:0] phase;
}scoreboard_t;

typedef struct packed {
    logic delay_opA;
    logic delay_opB;
    regid_t regA;
    regid_t regB;
    function_unit_t fuA;
    function_unit_t fuB;
} delay_exec_t;

typedef struct packed {
    logic valid;
    logic is_ret;
    logic is_call;
    logic must_jump;
    addr_t PC;
    addr_t jump_PC;
    opcode_t opcode;
} branch_buffer_t;

typedef struct packed{
    logic en;
    //delay_exec_t delay_exec;
    word_t opA;
    word_t opB;
    shamt_t shamt;
    arith_t operator;
}ALU_input_t;

typedef struct packed {
    logic en;
    logic is_ret;
    logic is_call;
    //delay_exec_t delay_exec;
    word_t opA;
    word_t opB;
    compare_t operator;
    logic branch_taken;
    addr_t link_PC;
    addr_t jump_PC;
    addr_t predict_PC;
    logic DS_RI;
}BRU_input_t;

typedef struct packed {
    logic en;
    addr_t base;
    word_t offset;
    addr_t jump_PC;
    logic mem_read;
    logic mem_write;
    logic unsign_en;
    msize_t msize;
    word_t data;
}AGU_input_t;

typedef struct packed {
    logic en;
    logic write_hi;
    logic write_lo;
    logic read_hi;
    logic read_lo;
    word_t data;
}HILO_input_t;

typedef struct packed{
    logic en;
    word_t opA;
    word_t opB;
    logic signed_en;
}MLT_input_t;

typedef struct packed{
    logic en;
    word_t opA;
    word_t opB;
    logic signed_a_en;
    logic signed_b_en;
}DIV_input_t;

typedef struct packed{
    logic en;
    logic mf;
    logic mt;
    word_t write_data;
    logic[7:0] regsel;
    logic eret;
    logic first;
    logic second;
    addr_t PC;
}COP0_input_t;

typedef struct packed{
    logic ALU1_OV;
    logic ALU2_OV;
    logic AGU_AdEL;
    logic BRU_AdEL;
    logic COP0_AdEL;
    logic AGU_AdES;
    logic ALU1_SYS;
    logic ALU2_SYS;
    logic ALU1_BR;
    logic ALU2_BR;
    logic COP0_eret;
    addr_t AGU_BadVAddr;
    addr_t BRU_BadVAddr;
    addr_t COP0_BadVAddr;
    logic COP0_first;
    logic COP0_second;
} exception_collector_t;

typedef struct packed {
    logic en;
    addr_t PC;
    function_unit_t fu; 
    regid_t target_reg;
    logic RI;
}exec_reg_t;

typedef struct packed {
    ALU_input_t ALU1_input;
    ALU_input_t ALU2_input;
    BRU_input_t BRU_input;
    AGU_input_t AGU_input;
    MLT_input_t MLT_input;
    DIV_input_t DIV_input;
    HILO_input_t HILO_input;
    COP0_input_t COP0_input;
    exec_reg_t exec_reg1;
    exec_reg_t exec_reg2;
}exec_input_t;

typedef struct packed {   
    word_t ALU1_result;   
    word_t ALU2_result;   
    addr_t BRU_link_PC;
    word_t COP0_result;
    MLT_input_t MLT_in; 
    AGU_input_t AGU_input;
    dbus_req_t dreq;
    word_t[3:0] MLT_p;    
    logic[63:0] DIV_result;
    exec_reg_t exec_reg1; 
    exec_reg_t exec_reg2; 
    logic write_hi;
    logic write_lo;
    word_t HILO_result;
    exception_collector_t exception_collector;
}exec_pipeline_reg_t;  

typedef struct packed {
    word_t ALU1_result;
    word_t ALU2_result;
    addr_t BRU_link_PC;   
    word_t AGU_result;
    word_t COP0_result;  
    logic[63:0] MLT_result;
    logic[63:0] DIV_result;
    logic write_hi;
    logic write_lo;
    word_t HILO_result;
    exec_reg_t exec_reg1; 
    exec_reg_t exec_reg2;
    exception_collector_t exception_collector;
}exec_result_t;

//cp0 defs
typedef enum i5 {
    EX_INT      = 0,   // Interrupt
    EX_MOD      = 1,   // TLB modification exception
    EX_TLBL     = 2,   // TLB exception (load or instruction fetch)
    EX_TLBS     = 3,   // TLB exception (store)
    EX_ADEL     = 4,   // Address error exception (load or instruction fetch)
    EX_ADES     = 5,   // Address error exception (store)
    EX_IBE      = 6,   // Bus error exception (instruction fetch)
    EX_DBE      = 7,   // Bus error exception (data reference: load or store)
    EX_SYS      = 8,   // Syscall exception
    EX_BP       = 9,   // Breakpoint exception
    EX_RI       = 10,  // Reserved instruction exception
    EX_CPU      = 11,  // Coprocessor Unusable exception
    EX_OV       = 12,  // Arithmetic Overflow exception
    EX_TR       = 13,  // Trap exception
    EX_FPE      = 15,  // Floating point exception
    EX_C2E      = 18,  // Reserved for precise Coprocessor 2 exceptions
    EX_TLBRI    = 19,  // TLB Read-Inhibit exception
    EX_TLBXI    = 20,  // TLB Execution-Inhibit exception
    EX_MDMX     = 22,  // MDMX Unusable Exception (MDMX ASE)
    EX_WATCH    = 23,  // Reference to WatchHi/WatchLo address
    EX_MCHECK   = 24,  // Machine check
    EX_THREAD   = 25,  // Thread Allocation, Deallocation, or Scheduling Exceptions (MIPS® MT ASE)
    EX_DSPDIS   = 26,  // DSP ASE State Disabled exception (MIPS® DSP ASE)
    EX_CACHEERR = 30,   // Cache error
    EX_NONE = 31
} ecode_t;

typedef enum i8 {
    RS_BADVADDR = {5'd8,  3'd0},
    RS_COUNT    = {5'd9,  3'd0},
    RS_COMPARE  = {5'd11, 3'd0},
    RS_STATUS   = {5'd12, 3'd0},
    RS_CAUSE    = {5'd13, 3'd0},
    RS_EPC      = {5'd14, 3'd0},
    RS_PRID     = {5'd15, 3'd0},
    RS_CONFIG   = {5'd16, 3'd0},
    RS_CONFIG1  = {5'd16, 3'd1},
    RS_ERROREPC = {5'd30, 3'd0}
} regsel_t;

typedef struct packed {
    i4 CU;    // [31:28]: access to coprocessors
    i1 RP;    // 27: optional
    i1 FR;    // 26: floating point registers, optional
    i1 RE;    // 25: optional
    i1 MX;    // 24: optional
    i1 RES1;  // 23: reserved
    i1 BEV;   // 22: location of exception vectors
    i1 TS;    // 21: optional
    i1 SR;    // 20: optional
    i1 NMI;   // 19: optional
    i1 ASE;   // 18: optional
    i2 RES2;  // [17:16]: reserved
    i8 IM;    // [15:8]: interrupt masks IM7~IM0
    i3 RES3;  // [7:5]: reserved
    i2 KSU;   // [4:3]: supervisor mode, optional
    i1 ERL;   // 2: error level
    i1 EXL;   // 1: exception level
    i1 IE;    // 0: interrupt enable
} cp0_status_t;

parameter cp0_status_t CP0_STATUS_RESET = '{
    CU  : 4'b0001,
    BEV : 1'b1,
    ERL : 1'b1,

    default: '0
};

parameter cp0_status_t CP0_STATUS_MASK = '{
    CU  : 4'b0001,  // CU0 is writable, although it's ignored.
    RP  : 1'b1,
    FR  : 1'b1,
    RE  : 1'b1,
    BEV : 1'b1,
    TS  :  1'b1,
    SR  :  1'b1,
    NMI : 1'b1,
    IM  : 8'hff,
    KSU  : 2'b10,
    ERL : 1'b1,
    EXL : 1'b1,
    IE  : 1'b1,

    default: '0
};

typedef struct packed {
    i1      BD;       // 31: in branch delay slot?
    i1      TI;       // 30: timer interrupt, in Release 2
    i2      CE;       // [29:28]: coprocessor unit number
    i1      DC;       // 27: optional
    i1      PCI;      // 26: performance counter interrupt, in Release 2
    i2      ASE1;     // [25:24]: reserved
    i1      IV;       // 23: interrupt vector
    i1      WP;       // 22: optional
    i1      FDCI;     // 21: optional
    i5      RES1;     // [20:16]: reserved
    i8      IP;       // [15:8]: interrupt requests
    i1      RES2;     // 7: reserved
    ecode_t ExcCode;  // [6:2]: exception code
    i2      RES3;     // [1:0]: reserved
} cp0_cause_t;

parameter cp0_cause_t CP0_CAUSE_MASK = '{
    DC  : 1'b1,
    IV : 1'b1,
    WP  : 1'b1,
    IP : 8'h03,

    default: '0
};

typedef struct packed {
    // we sort members descending in ther register number,
    // due to a misbehavior of little endian bit numbering array
    // in Verilator.
    addr_t        ErrorEPC;
    addr_t        EPC;
    cp0_cause_t   Cause;
    cp0_status_t  Status;
    word_t        Compare;
    word_t        Count;
    addr_t        BadVAddr;
} cp0_regfile_t;

typedef struct packed {
    logic exception_en;
    logic BD;
    addr_t EPC;
    addr_t BadVAddr;
    ecode_t ExeCode;
} cp0_reg_input_t;

`endif