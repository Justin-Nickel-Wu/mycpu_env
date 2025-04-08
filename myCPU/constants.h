`ifndef CONSTAINS
    `define CONSTAINS
    `define to_ID_data_width  65
    `define to_EX_data_width  223
    `define to_MEM_data_width 137
    `define to_WB_data_width  130
    `define br_data_width     33
    `define forwrd_data_width  38

    `define CSR_NUM_WIDTH 14

    `define CSR_CRMD      `CSR_NUM_WIDTH'h0
    `define CSR_PRMD      `CSR_NUM_WIDTH'h1
    `define CSR_EUEN      `CSR_NUM_WIDTH'h2
    `define CSR_ECFG      `CSR_NUM_WIDTH'h4
    `define CSR_ESTAT     `CSR_NUM_WIDTH'h5
    `define CSR_ERA       `CSR_NUM_WIDTH'h6
    `define CSR_BADV      `CSR_NUM_WIDTH'h7
    `define CSR_EENTRY    `CSR_NUM_WIDTH'hc
    `define CSR_TLBIDX    `CSR_NUM_WIDTH'h10
    `define CSR_TLBEHI    `CSR_NUM_WIDTH'h11
    `define CSR_TLBELO0   `CSR_NUM_WIDTH'h12
    `define CSR_TLBELO1   `CSR_NUM_WIDTH'h13
    `define CSR_ASID      `CSR_NUM_WIDTH'h18
    `define CSR_PGDL      `CSR_NUM_WIDTH'h19
    `define CSR_PGDH      `CSR_NUM_WIDTH'h1a
    `define CSR_PGD       `CSR_NUM_WIDTH'h1b
    `define CSR_CPUID     `CSR_NUM_WIDTH'h20
    `define CSR_SAVE0     `CSR_NUM_WIDTH'h30
    `define CSR_SAVE1     `CSR_NUM_WIDTH'h31
    `define CSR_SAVE2     `CSR_NUM_WIDTH'h32
    `define CSR_SAVE3     `CSR_NUM_WIDTH'h33
    `define CSR_TID       `CSR_NUM_WIDTH'h40
    `define CSR_TCFG      `CSR_NUM_WIDTH'h41
    `define CSR_TVAL      `CSR_NUM_WIDTH'h42
    `define CSR_TICLR     `CSR_NUM_WIDTH'h44
    `define CSR_LLBCTL    `CSR_NUM_WIDTH'h60
    `define CSR_TLBRENTRY `CSR_NUM_WIDTH'h88
    `define CSR_CTAG      `CSR_NUM_WIDTH'h98
    `define CSR_DMW0      `CSR_NUM_WIDTH'h180
    `define CSR_DMW1      `CSR_NUM_WIDTH'h181

    `define ECODE_ADE       6'h8
    `define ECODE_ALE       6'h9
    `define ESUBCODE_ADEF   9'h0

    `define CSR_CRMD_PLV      1:0
    `define CSR_CRMD_IE       2
    `define CSR_PRMD_PPLV     1:0
    `define CSR_PRMD_PIE      2
    `define CSR_ECFG_LIE      12:0
    `define CSR_ESTAT_IS10    1:0
    `define CSR_ERA_PC        31:0
    `define CSR_BADV_VADDR    31:0
    `define CSR_EENTRY_VA     31:6
    `define CSR_SAVE_DATA     31:0
    `define CSR_TID_TID       31:0
    `define CSR_TCFG_EN       0
    `define CSR_TCFG_PERIODIC 1
    `define CSR_TCFG_INITVAL  31:2
    `define CSR_TICLR_CLR     0

`endif