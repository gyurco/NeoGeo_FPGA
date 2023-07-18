//============================================================================
//  SNK NeoGeo top-level, FPGA-independent synchronous version
//  Copyright (C) 2023 Gyorgy Szombathelyi
//
//  Based on SNK NeoGeo for MiSTer
//  Copyright (C) 2018 Sean 'Furrtek' Gonsalves
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module neogeo_top
(
	input         CLK_48M,
	input         RESET,

	input   [1:0] SYSTEM_TYPE,
	input         VIDEO_MODE,
	input         MEMCARD_EN,
	input   [2:0] DIPSW,
	input         COIN1,
	input         COIN2,
	input   [9:0] P1_IN,
	input   [9:0] P2_IN,
	output reg    MS_XY,
	input         DBG_FIX_EN,
	input         DBG_SPR_EN,
	input  [63:0] RTC,

	// video
	output reg [7:0] RED,
	output reg [7:0] GREEN,
	output reg [7:0] BLUE,
	output        HSYNC,
	output        VSYNC,
	output reg    HBLANK,
	output reg    VBLANK,
	output        CE_PIXEL,

	// audio
	output [15:0] LSOUND,
	output [15:0] RSOUND,

	// cartridge hardware variants
	input   [3:0] CART_PCHIP,
	input   [1:0] CART_CHIP,     // legacy option: 0 - none, 1 - PRO-CT0, 2 - Link MCU
	input   [1:0] CMC_CHIP,      // type 1/2
	input         ROM_WAIT,      // ROMWAIT from cart. 0 - Full speed, 1 - 1 wait cycle
	input   [1:0] P_WAIT,        // PWAIT from cart. 0 - Full speed, 1 - 1 wait cycle, 2 - 2 cycles	

	// memcard save-load
	input         CLK_MEMCARD,
	input  [11:0] MEMCARD_ADDR,
	input         MEMCARD_WR,
	input  [15:0] MEMCARD_DIN,
	output [15:0] MEMCARD_DOUT,

	// CD
	input   [1:0] CD_REGION_SEL,
	input   [1:0] CD_SPEED,
	input         CD_LID,

	input         CD_DATA_DOWNLOAD,
	input         CD_DATA_WR,
	output        CD_DATA_WR_READY,
	input         CDDA_WR,
	output        CDDA_WR_READY,
	input  [15:0] CD_DATA_DIN,
	input  [11:1] CD_DATA_ADDR,
	input  [39:0] CDD_STATUS_IN,
	input         CDD_STATUS_LATCH,
	output [39:0] CDD_COMMAND_DATA,
	output        CDD_COMMAND_SEND,
	output [15:0] CD_AUDIO_L,
	output [15:0] CD_AUDIO_R,

	// external RAM/ROM signals
	output [14:0] SLOW_SCB1_VRAM_ADDR,
	input  [15:0] SLOW_SCB1_VRAM_DATA_IN,
	output [15:0] SLOW_SCB1_VRAM_DATA_OUT,
	output        SLOW_SCB1_VRAM_RD,
	output        SLOW_SCB1_VRAM_WE,

	output [14:0] SPRMAP_ADDR,
	output        SPRMAP_RD,
	input  [31:0] SPRMAP_DATA,

	output [15:0] LO_ROM_ADDR,
	output        LO_ROM_RD,
	input   [7:0] LO_ROM_DATA,

	output [23:0] P2ROM_ADDR,
	input  [15:0] PROM_DATA,
	output [15:0] PROM_DOUT,
	output  [1:0] PROM_DS,
	input         PROM_DATA_READY,
	output        ROM_RD,
	output        PORT_RD,
	output        SROM_RD,
	output        WRAM_WE,
	output        WRAM_RD,
	output        SRAM_WE,
	output        SRAM_RD,
	output        CD_EXT_RD, // CD $000000~$1FFFFF
	output        CD_EXT_WR,
	output        CD_FIX_RD,
	output        CD_FIX_WR,
	output        CD_SPR_RD,
	output        CD_SPR_WR,
	output        CD_PCM_RD,
	output        CD_PCM_WR,

	output        SYSTEM_ROMS,

	output [17:0] SFIX_ADDR,
	input  [15:0] SFIX_DATA,
	output        SFIX_RD,

	output [26:0] CROM_ADDR,
	input  [31:0] CROM_DATA,
	output        CROM_RD,

	output [18:0] Z80_ROM_ADDR,
	output  [7:0] Z80_ROM_DOUT,
	output        Z80_ROM_RD,
	output        Z80_ROM_WR,
	input   [7:0] Z80_ROM_DATA,
	input         Z80_ROM_READY,

	output [19:0] ADPCMA_ADDR,
	output  [3:0] ADPCMA_BANK,
	output        ADPCMA_RD,
	input   [7:0] ADPCMA_DATA,
	input         ADPCMA_DATA_READY,
	output [23:0] ADPCMB_ADDR,
	output        ADPCMB_RD,
	input   [7:0] ADPCMB_DATA,
	input         ADPCMB_DATA_READY
);

assign LSOUND = snd_left;
assign RSOUND = snd_right;

wire SYSTEM_MVS = (SYSTEM_TYPE == 2'd1);
wire SYSTEM_CDx = SYSTEM_TYPE[1];
wire SYSTEM_CDZ = (SYSTEM_TYPE == 2'd3);

wire nRESET = ~RESET;

assign ROM_RD = ~nROMOE;
assign PORT_RD = ~nPORTOE;
assign SROM_RD = ~nSROMOE;
assign CD_FIX_RD = CD_TR_RD_FIX;
assign CD_FIX_WR = CD_TR_WR_FIX;
assign CD_SPR_RD = CD_TR_RD_SPR;
assign CD_SPR_WR = CD_TR_WR_SPR;
assign CD_PCM_RD = CD_TR_RD_PCM;
assign CD_PCM_WR = CD_TR_WR_PCM;

reg CLK_EN_24M_N, CLK_EN_24M_P;
always @(posedge CLK_48M) begin
	CLK_EN_24M_N <= ~CLK_EN_24M_N;
	CLK_EN_24M_P <= CLK_EN_24M_N;
end
//////////////////   Her Majesty   ///////////////////

wire [15:0] snd_right;
wire [15:0] snd_left;

wire nRESETP, nSYSTEM, CARD_WE, SHADOW, nVEC, nREGEN, nSRAMWEN, PALBNK;
wire CD_nRESET_Z80;

// Clocks
wire CLK_24M, CLK_12M, CLK_EN_12M, CLK_EN_12M_N, CLK_68KCLK, CLK_68KCLKB, CLK_EN_6MB, CLK_EN_1HB, CLK_EN_4M_P, CLK_EN_4M_N, CLK_EN_68K_P, CLK_EN_68K_N;

// 68k stuff
wire [15:0] M68K_DATA;
wire [23:1] M68K_ADDR;
wire A22Z, A23Z;
wire M68K_RW, nAS, nLDS, nUDS, nDTACK, nHALT, nBR, nBG, nBGACK;
wire [15:0] M68K_DATA_BYTE_MASK;
wire [15:0] FX68K_DATAIN;
wire [15:0] FX68K_DATAOUT;
wire IPL0, IPL1;
wire FC0, FC1, FC2;
reg [3:0] P_BANK;

// RTC stuff
wire RTC_DOUT, RTC_DIN, RTC_CLK, RTC_STROBE, RTC_TP;

// OEs and WEs
wire nSROMOEL, nSROMOEU, nSROMOE;
wire nROMOEL, nROMOEU;
wire nPORTOEL, nPORTOEU, nPORTWEL, nPORTWEU, nPORTADRS;
wire nSRAMOEL, nSRAMOEU, nSRAMWEL, nSRAMWEU;
wire nWRL, nWRU, nWWL, nWWU;
wire nLSPOE, nLSPWE;
wire nPAL, nPAL_WE;
wire nBITW0, nBITW1, nBITWD0, nDIPRD0, nDIPRD1;
wire nSDROE, nSDPOE;

// RAM outputs
wire [7:0] WRAML_OUT;
wire [7:0] WRAMU_OUT;
wire [15:0] SRAM_OUT;

// Memory card stuff
wire [23:0] CDA;
wire [2:0] BNK;
wire [7:0] CDD;
wire nCD1, nCD2;
wire nCRDO, nCRDW, nCRDC;
wire nCARDWEN, CARDWENB;

// Z80 stuff
wire [7:0] SDD_IN, SDD_OUT, Z80_SDD_OUT;
wire [7:0] SDD_RD_C1;
wire [15:0] SDA, Z80_SDA;
wire nSDRD, nSDWR, nMREQ, nIORQ, nBUSAK;
wire nZ80_SDRD, nZ80_SDWR, nZ80_MREQ;
wire nZ80INT, nZ80NMI, nSDW, nSDZ80R, nSDZ80W, nSDZ80CLR;
wire nSDROM, nSDMRD, nSDMWR, SDRD0, SDRD1, nZRAMCS;
wire n2610CS, n2610RD, n2610WR;

// Graphics stuff
wire [23:0] PBUS;
wire nPBUS_OUT_EN;

wire [19:0] C_LATCH;
reg   [3:0] C_LATCH_EXT;

wire [1:0] FIX_BANK;
wire [15:0] S_LATCH;
wire [7:0] FIXD;
wire [10:0] FIXMAP_ADDR;

wire CWE, BWE, BOE;

wire  [1:0] VRAM_CYCLE;
wire        VRAM_SPRMAP_CYCLE = VRAM_CYCLE == 2'b10;
wire        VRAM_FIXMAP_CYCLE = VRAM_CYCLE == 2'b00;
wire        VRAM_CPU_CYCLE    = VRAM_CYCLE == 2'b01;
assign      LO_ROM_RD = VRAM_FIXMAP_CYCLE; // lo rom address is ready here

wire        SLOW_VRAM_WR;
wire [14:0] SLOW_VRAM_ADDR;
wire [15:0] SLOW_VRAM_DATA_OUT;
wire [15:0] CPU_VRAM_ADDR;
// use external RAM if VRAM32 is defined, otherwise use internal BRAM
`ifdef VRAM32
wire [15:0] SLOW_FIX_VRAM_DATA_IN;
wire        SCB1_CS = CPU_VRAM_ADDR[15:12] < 4'd7;
wire [31:0] SLOW_VRAM_DATA_IN = VRAM_SPRMAP_CYCLE ? SPRMAP_DATA : (SCB1_CS & VRAM_CPU_CYCLE) ? SLOW_SCB1_VRAM_DATA_IN : SLOW_FIX_VRAM_DATA_IN;
assign      SLOW_SCB1_VRAM_WE =  SLOW_VRAM_WR && SCB1_CS && VRAM_CPU_CYCLE;
assign      SLOW_SCB1_VRAM_RD = ~SLOW_VRAM_WR && SCB1_CS && VRAM_CPU_CYCLE;
assign      SLOW_SCB1_VRAM_ADDR = CPU_VRAM_ADDR[15:0];
assign      SLOW_SCB1_VRAM_DATA_OUT = SLOW_VRAM_DATA_OUT;
assign      SPRMAP_RD = VRAM_SPRMAP_CYCLE | VRAM_FIXMAP_CYCLE; // the address is ready even in the fixmap read cycle
`else
wire [15:0] SLOW_VRAM_DATA_IN;
assign      SLOW_SCB1_VRAM_RD = 0;
assign      SLOW_SCB1_VRAM_WE = 0;
assign      SPRMAP_RD = 0;
assign      SLOW_SCB1_VRAM_DATA_OUT = 0;
assign      SLOW_SCB1_VRAM_ADDR = 0;
`endif

wire [10:0] FAST_VRAM_ADDR;
wire [15:0] FAST_VRAM_DATA_IN;
wire [15:0] FAST_VRAM_DATA_OUT;

wire [11:0] PAL_RAM_ADDR;
wire [15:0] PAL_RAM_DATA;
reg [15:0] PAL_RAM_REG;

wire PCK1, PCK2, EVEN1, EVEN2, LOAD, H;
wire PCK1_EN_P, PCK2_EN_P;
wire PCK1_EN_N, PCK2_EN_N;
wire DOTA, DOTB;
wire CA4, S1H1, S2H1;
wire CHBL, nBNKB, VCS;
wire CHG, LD1, LD2, SS1, SS2;
wire [3:0] GAD;
wire [3:0] GBD;
wire [3:0] WE;
wire [3:0] CK;

wire CD_VIDEO_EN, CD_FIX_EN, CD_SPR_EN;

// SDRAM multiplexing stuff
assign SFIX_ADDR = {FIX_BANK, S_LATCH[15:4], S_LATCH[2:0], ~S_LATCH[3]};
assign SFIX_RD = PCK2;
wire [15:0] SROM_DATA = SFIX_DATA;
//wire [15:0] PROM_DATA;

// Memory write flag for backup memory & memory card
// (~nBWL | ~nBWU) : [AES] Unibios (set to MVS) softdip settings, [MVS] cab settings, dates, timer, high scores, saves, & bookkeeeping
// CARD_WE         : [AES/MVS] game saves and high scores
wire bk_change = sram_slot_we | CARD_WE;
wire memcard_change;

reg sram_slot_we;
always @(posedge CLK_48M) begin
	sram_slot_we <= 0;
	if(~nBWL | ~nBWU) begin
		sram_slot_we <= (M68K_ADDR[15:1] >= 'h190 && M68K_ADDR[15:1] < 'h4190);
	end
end

reg [1:0] CD_REGION;
always @(CD_REGION_SEL)
begin
	// CD Region code remap:
	// status[11:10] remap
	// 00            10 US
	// 01            01 EU
	// 10            11 JP
	// 11            00 ASIA
	case(CD_REGION_SEL)
		 2'b00: CD_REGION = 2'b10;
		 2'b01: CD_REGION = 2'b01;
		 2'b10: CD_REGION = 2'b11;
		 2'b11: CD_REGION = 2'b00;
	endcase
end

wire [2:0] CD_TR_AREA;	// Transfer area code
wire [15:0] CD_TR_WR_DATA;
wire [19:1] CD_TR_WR_ADDR;
wire [1:0] CD_BANK_SPR;

wire CD_TR_WR_SPR, CD_TR_WR_PCM, CD_TR_WR_Z80, CD_TR_WR_FIX;
wire CD_TR_RD_SPR, CD_TR_RD_PCM, CD_TR_RD_FIX, CD_TR_RD_Z80;
wire CD_USE_SPR, CD_USE_FIX, CD_USE_Z80;
wire CD_UPLOAD_EN;
wire CD_BANK_PCM;
wire CD_IRQ;
wire CD_VBLANK_IRQ_EN, CD_TIMER_IRQ_EN;
wire DMA_RUNNING, DMA_WR_OUT, DMA_RD_OUT;
wire [15:0] DMA_DATA_OUT;
wire [23:0] DMA_ADDR_IN;
wire [23:0] DMA_ADDR_OUT;
wire [15:0] DMA_DATA_IN;

wire DMA_SDRAM_BUSY = (CD_EXT_RD | CD_EXT_WR | CD_TR_RD_FIX | CD_TR_WR_FIX | CD_TR_RD_SPR | CD_TR_WR_SPR | CD_TR_RD_PCM | CD_TR_WR_PCM) ? ~PROM_DATA_READY :
                  (CD_TR_WR_Z80 | CD_TR_RD_Z80) ? ~nZ80WAIT : 1'b0;

wire CDDA_CLK;
CEGen CEGEN_CDDA_CLK
(
	.CLK(CLK_48M),
	.RST_N(nRESET),
	.IN_CLK(48000000),
	.OUT_CLK(44100),
	.CE(CDDA_CLK)
);


`ifdef NO_CD
assign nBR = 1'b1;
assign nBGACK  = 1'b1;
`else
cd_sys #(.MCLK(48000000)) cdsystem(
	.nRESET(nRESET),
	.clk_sys(CLK_48M), .CLK_68KCLK_EN(CLK_EN_68K_P),
	.M68K_ADDR(M68K_ADDR), .M68K_DATA(M68K_DATA), .A22Z(A22Z), .A23Z(A23Z),
	.nLDS(nLDS), .nUDS(nUDS), .M68K_RW(M68K_RW), .nAS(nAS), .nDTACK(nDTACK_ADJ),
	.nBR(nBR), .nBG(nBG), .nBGACK(nBGACK),
	.SYSTEM_CDx(SYSTEM_CDx),
	.CD_REGION(CD_REGION),
	.CD_SPEED(CD_SPEED),
	.CD_LID(CD_LID ^ SYSTEM_CDZ),	// CD lid state (DEBUG)
	.CD_VIDEO_EN(CD_VIDEO_EN), .CD_FIX_EN(CD_FIX_EN), .CD_SPR_EN(CD_SPR_EN),
	.CD_nRESET_Z80(CD_nRESET_Z80),
	.CD_TR_RD_SPR(CD_TR_RD_SPR), .CD_TR_WR_SPR(CD_TR_WR_SPR),
	.CD_TR_RD_PCM(CD_TR_RD_PCM), .CD_TR_WR_PCM(CD_TR_WR_PCM),
	.CD_TR_RD_FIX(CD_TR_RD_FIX), .CD_TR_WR_FIX(CD_TR_WR_FIX),
	.CD_TR_RD_Z80(CD_TR_RD_Z80), .CD_TR_WR_Z80(CD_TR_WR_Z80), 
	.CD_USE_FIX(CD_USE_FIX), .CD_USE_SPR(CD_USE_SPR),
	.CD_USE_Z80(CD_USE_Z80),
	.CD_TR_AREA(CD_TR_AREA),
	.CD_BANK_SPR(CD_BANK_SPR), .CD_BANK_PCM(CD_BANK_PCM),
	.CD_TR_WR_DATA(CD_TR_WR_DATA), .CD_TR_WR_ADDR(CD_TR_WR_ADDR),
	.CD_UPLOAD_EN(CD_UPLOAD_EN),
	.CD_IRQ(CD_IRQ), .IACK(IACK),
	.CD_VBLANK_IRQ_EN(CD_VBLANK_IRQ_EN), .CD_TIMER_IRQ_EN(CD_TIMER_IRQ_EN),
	.CDD_STATUS_IN(CDD_STATUS_IN), .CDD_STATUS_LATCH(CDD_STATUS_LATCH),
	.CDD_COMMAND_DATA(CDD_COMMAND_DATA), .CDD_COMMAND_SEND(CDD_COMMAND_SEND),
	.CD_DATA_DOWNLOAD(CD_DATA_DOWNLOAD), .CD_DATA_WR(CD_DATA_WR),
	.CD_DATA_DIN(CD_DATA_DIN),
	.CD_DATA_ADDR(CD_DATA_ADDR),
	.CD_DATA_WR_READY(CD_DATA_WR_READY),
	.CDDA_RD(CDDA_CLK), .CDDA_WR(CDDA_WR),
	.CDDA_WR_READY(CDDA_WR_READY),
	.CD_AUDIO_L(CD_AUDIO_L), .CD_AUDIO_R(CD_AUDIO_R),
	.DMA_RUNNING(DMA_RUNNING),
	.DMA_DATA_IN(DMA_DATA_IN), .DMA_DATA_OUT(DMA_DATA_OUT),
	.DMA_WR_OUT(DMA_WR_OUT), .DMA_RD_OUT(DMA_RD_OUT),
	.DMA_ADDR_IN(DMA_ADDR_IN),		// Used for reading
	.DMA_ADDR_OUT(DMA_ADDR_OUT),	// Used for writing
	.DMA_SDRAM_BUSY(DMA_SDRAM_BUSY)
);
`endif

// The P1 zone is writable on the Neo CD
// Is there a write enable register for it ?
assign CD_EXT_WR = DMA_RUNNING ? (SYSTEM_CDx & (DMA_ADDR_OUT[23:21] == 3'd0) & DMA_WR_OUT) :    // DMA writes to $000000~$1FFFFF
              (SYSTEM_CDx & ~|{A23Z, A22Z, M68K_ADDR[21]} & ~M68K_RW & ~nAS & (~nUDS | ~nLDS)); // CPU writes to $000000~$1FFFFF

wire nROMOE = nROMOEL & nROMOEU;
wire nPORTOE = nPORTOEL & nPORTOEU;

// CD system work ram is in SDRAM
assign CD_EXT_RD = DMA_RUNNING ? (SYSTEM_CDx & (DMA_ADDR_IN[23:21] == 3'd0) & DMA_RD_OUT) :     // DMA reads from $000000~$1FFFFF
                                 (SYSTEM_CDx & (~nWRL | ~nWRU));                                // CPU reads from $100000~$1FFFFF

neo_d0 D0(
	.CLK(CLK_48M),
	.CLK_EN_24M_P(CLK_EN_24M_P),
	.CLK_EN_24M_N(CLK_EN_24M_N),
	.CLK_24M(CLK_24M),
	.nRESET(nRESET), .nRESETP(nRESETP),
	.CLK_12M(CLK_12M), .CLK_68KCLK(CLK_68KCLK), .CLK_68KCLKB(CLK_68KCLKB), .CLK_EN_12M(CLK_EN_12M), .CLK_EN_12M_N(CLK_EN_12M_N), .CLK_EN_6MB(CLK_EN_6MB), .CLK_EN_1HB(CLK_EN_1HB),
	.CLK_EN_68K_P(CLK_EN_68K_P), .CLK_EN_68K_N(CLK_EN_68K_N),
	.M68K_ADDR_A4(M68K_ADDR[4]),
	.M68K_DATA(M68K_DATA[5:0]),
	.nBITWD0(nBITWD0),
	.SDA_H(SDA[15:11]), .SDA_L(SDA[4:2]),
	.nSDRD(nSDRD),	.nSDWR(nSDWR), .nMREQ(nMREQ),	.nIORQ(nIORQ),
	.nZ80NMI(nZ80NMI),
	.nSDW(nSDW), .nSDZ80R(nSDZ80R), .nSDZ80W(nSDZ80W),	.nSDZ80CLR(nSDZ80CLR),
	.nSDROM(nSDROM), .nSDMRD(nSDMRD), .nSDMWR(nSDMWR), .nZRAMCS(nZRAMCS),
	.SDRD0(SDRD0),	.SDRD1(SDRD1),
	.n2610CS(n2610CS), .n2610RD(n2610RD), .n2610WR(n2610WR),
	.BNK(BNK)
);


// Re-priority-encode the interrupt lines with the CD_IRQ one (IPL* are active-low)
//
//  IPL2 IPL1 IPL0    Cartridge        CD
//    1    1    1     No IRQ           No IRQ
//    1    1    0     Vblank    (64)   Vblank (68)
//    1    0    1     Timer     (68)   CD IRQ (54/58)
//    1    0    0     Cold boot (6C)   Timer  (64)
//
wire [1:0] CD_IPL = (!IPL1 & IPL0) ? 2'b00 // Level 3 Timer
                  : CD_IRQ ? 2'b01         // Level 2 CD IRQ
                  : (IPL1 & !IPL0) ? 2'b10 // Level 1 VBlank
                  : 2'b11;

wire [1:0] IPL_OUT = ~SYSTEM_CDx ? { IPL1,IPL0 } : CD_IPL;

// Because of the SDRAM latency, nDTACK is handled differently for ROM zones
// If the address is in a ROM zone, PROM_DATA_READY is used to extend the normal nDTACK output by NEO-C1
wire nDTACK_ADJ = ~&{nSROMOE, nROMOE, nPORTOE, ~WRAM_RD, ~WRAM_WE, ~SRAM_RD, ~SRAM_WE, ~CD_EXT_RD, ~CD_EXT_WR, ~CD_TR_RD_FIX, ~CD_TR_WR_FIX, ~CD_TR_RD_SPR, ~CD_TR_WR_SPR, ~CD_TR_RD_PCM, ~CD_TR_WR_PCM} ? ~PROM_DATA_READY | nDTACK :
                  (CD_TR_RD_Z80 | CD_TR_WR_Z80) ? ~nZ80WAIT | nDTACK : nDTACK;

cpu_68k M68KCPU(
	.CLK(CLK_48M),
	.CLK_EN_68K_P(CLK_EN_68K_P),
	.CLK_EN_68K_N(CLK_EN_68K_N),
	.nRESET(nRESET_WD),
	.M68K_ADDR(M68K_ADDR),
	.FX68K_DATAIN(FX68K_DATAIN), .FX68K_DATAOUT(FX68K_DATAOUT),
	.nLDS(nLDS), .nUDS(nUDS), .nAS(nAS), .M68K_RW(M68K_RW),
	.nDTACK(nDTACK_ADJ),	// nDTACK
	.IPL2(1'b1), .IPL1(IPL_OUT[1]), .IPL0(IPL_OUT[0]),
	.FC2(FC2), .FC1(FC1), .FC0(FC0),
	.nBG(nBG), .nBR(nBR), .nBGACK(nBGACK),
	.SYSTEM_CDx(SYSTEM_CDx)
);

wire IACK = &{FC2, FC1, FC0};

// FX68K doesn't like byte masking with Z's, replace with 0's:
assign FX68K_DATAIN = M68K_RW ? M68K_DATA : 16'h0000;
assign M68K_DATA = M68K_RW ? 16'bzzzzzzzz_zzzzzzzz : FX68K_DATAOUT;

// mouse axis selector
always @(posedge CLK_48M)
	if(!nBITW0 && !M68K_ADDR[6:3]) MS_XY <= M68K_DATA[0];

assign FIXD = CD_USE_FIX ? 8'bzzzz_zzzz : S2H1 ? SROM_DATA[15:8] : SROM_DATA[7:0];

// Disable ROM read in PORT zone if the game uses a special chip
assign M68K_DATA = ((nROMOE & nSROMOE & |{nPORTOE, CART_CHIP, CART_PCHIP}) | CD_TR_RD_FIX | CD_TR_RD_PCM) ? 16'bzzzzzzzzzzzzzzzz : PROM_DATA;

assign M68K_DATA = CD_TR_RD_SPR ? PROM_DATA : 16'hzzzz;
// Output correct FIX byte
assign M68K_DATA[7:0] = ~CD_TR_RD_FIX ? 8'bzzzz_zzzz : (M68K_ADDR[4] ? PROM_DATA[15:8] : PROM_DATA[7:0]);
// Output correct PCM byte
assign M68K_DATA[7:0] = ~CD_TR_RD_PCM ? 8'bzzzz_zzzz : (M68K_ADDR[1] ? PROM_DATA[15:8] : PROM_DATA[7:0]);

assign DMA_DATA_IN = CD_TR_RD_Z80 ? {SDD_IN, SDD_IN} : 
                     (CD_TR_RD_PCM | CD_TR_RD_FIX) ? (P2ROM_ADDR[0] ? {PROM_DATA[15:8], PROM_DATA[15:8]} : {PROM_DATA[7:0], PROM_DATA[7:0]}) :
					 PROM_DATA;


assign WRAM_WE = ~&{nWWU, nWWL};
assign WRAM_RD = ~&{nWRU, nWRL};
assign {WRAMU_OUT, WRAML_OUT} = PROM_DATA;

// 68k work RAM
/*
dpram #(15) WRAML(
	.clock_a(CLK_24M),
	.address_a(M68K_ADDR[15:1]),
	.data_a(M68K_DATA[7:0]),
	.wren_a(~nWWL),
	.q_a(WRAML_OUT),

	.clock_b(CLK_24M),
	.address_b(TRASH_ADDR),
	.data_b(TRASH_ADDR[7:0]),
	.wren_b(~nRESET)
);
*/
/*
dpram #(15) WRAMU(
	.clock_a(CLK_24M),
	.address_a(M68K_ADDR[15:1]),
	.data_a(M68K_DATA[15:8]),
	.wren_a(~nWWU),
	.q_a(WRAMU_OUT),

	.clock_b(CLK_24M),
	.address_b(TRASH_ADDR),
	.data_b(TRASH_ADDR[7:0]),
	.wren_b(~nRESET)
);
*/
wire [23:0] ADDR_MUX = DMA_RUNNING ? (({24{DMA_WR_OUT}} & DMA_ADDR_OUT) | ({24{DMA_RD_OUT}} & DMA_ADDR_IN)) : {3'd0, M68K_ADDR[20:1], 1'b0};

assign P2ROM_ADDR = ({24{(CD_EXT_RD | CD_EXT_WR | SRAM_RD | SRAM_WE | WRAM_RD | WRAM_WE)}} & ADDR_MUX) |
                    ({24{(CD_TR_RD_FIX | CD_TR_WR_FIX)}} & {ADDR_MUX[17:6], ADDR_MUX[3:1], ~ADDR_MUX[5], ADDR_MUX[4]}) |
                    ({24{(CD_TR_RD_SPR | CD_TR_WR_SPR)}} & {CD_BANK_SPR, ADDR_MUX[19:7], ADDR_MUX[5:2], ~ADDR_MUX[6], ADDR_MUX[1:0]}) |
					({24{(CD_TR_RD_PCM | CD_TR_WR_PCM)}} & {CD_BANK_PCM, ADDR_MUX[19:1]}) |
					({24{(!CART_PCHIP & !(nROMOE & nPORTOE & nSROMOE))}} & {P_BANK, ADDR_MUX[19:1], 1'b0}) |
					NEO_PVC_P2ROM_ADDR | NEO_SMA_P2ROM_ADDR;

wire [15:0] CD_TR_DOUT = DMA_RUNNING ? DMA_DATA_OUT : M68K_DATA;
assign PROM_DOUT = (CD_TR_WR_FIX | CD_TR_WR_PCM) ? {CD_TR_DOUT[7:0], CD_TR_DOUT[7:0]} : CD_TR_DOUT;
assign PROM_DS = (CD_TR_WR_FIX | CD_TR_WR_PCM) ? {P2ROM_ADDR[0], ~P2ROM_ADDR[0]} :
                 DMA_RUNNING ? 2'b11 : ~{nUDS, nLDS};
wire [23:0] NEO_PVC_P2ROM_ADDR;

neo_pvc neo_pvc
(
	.nRESET(nRESET),
	.CLK_48M(CLK_48M),

	.ENABLE(CART_PCHIP == 2),

	.M68K_ADDR(M68K_ADDR),
	.M68K_DATA(M68K_DATA),
	.PROM_DATA(PROM_DATA),
	.nPORTOEL(nPORTOEL),
	.nPORTOEU(nPORTOEU),
	.nPORTWEL(nPORTWEL),
	.nPORTWEU(nPORTWEU),
	.P2_ADDR(NEO_PVC_P2ROM_ADDR)
);

wire [23:0] NEO_SMA_P2ROM_ADDR;

neo_sma neo_sma
(
	.nRESET(nRESET),
	.CLK_48M(CLK_48M),

	.TYPE(CART_PCHIP),

	.M68K_ADDR(M68K_ADDR),
	.M68K_DATA(M68K_DATA),
	.PROM_DATA(PROM_DATA),
	.nPORTOEL(nPORTOEL),
	.nPORTOEU(nPORTOEU),
	.nPORTWEL(nPORTWEL),
	.nPORTWEU(nPORTWEU),
	.P2_ADDR(NEO_SMA_P2ROM_ADDR)
);

// Work RAM or CD extended RAM read
assign M68K_DATA[7:0]  = nWRL ? 8'bzzzzzzzz : SYSTEM_CDx ? PROM_DATA[7:0]  : WRAML_OUT;
assign M68K_DATA[15:8] = nWRU ? 8'bzzzzzzzz : SYSTEM_CDx ? PROM_DATA[15:8] : WRAMU_OUT;
/*
wire save_wr    =  sd_buff_wr & bk_ack;
wire sram_wr    = ~bk_lba[7] & save_wr; // 000000~00FFFF
wire memcard_wr =  bk_lba[7] & save_wr; // 010000-011FFF
wire [14:0] sram_addr    = {bk_lba[6:0], sd_buff_addr}; //64KB
wire [11:0] memcard_addr = {bk_lba[3:0], sd_buff_addr}; //8KB
*/
// Backup RAM
wire nBWL = nSRAMWEL | nSRAMWEN_G;
wire nBWU = nSRAMWEU | nSRAMWEN_G;
/*
wire [15:0] sram_buff_dout;
backup BACKUP(
	.CLK_24M(CLK_24M),
	.M68K_ADDR(M68K_ADDR[15:1]),
	.M68K_DATA(M68K_DATA),
	.nBWL(nBWL), .nBWU(nBWU),
	.SRAM_OUT(SRAM_OUT),
	.clk_sys(clk_sys),
	.sram_addr(sram_addr),
	.sram_wr(sram_wr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din_sram(sram_buff_dout)
);
*/
// Backup RAM is only for MVS
assign M68K_DATA[7:0] = (nSRAMOEL | ~SYSTEM_MVS) ? 8'bzzzzzzzz : SRAM_OUT[7:0];
assign M68K_DATA[15:8] = (nSRAMOEU | ~SYSTEM_MVS) ? 8'bzzzzzzzz : SRAM_OUT[15:8];

assign SRAM_WE = ~&{nBWU, nBWL};
assign SRAM_RD = ~&{nSRAMOEU, nSRAMOEL} & SYSTEM_MVS;
assign SRAM_OUT = PROM_DATA;

`ifdef DEMISTIFY_NO_MEMCARD
// Memory card
assign {nCD1, nCD2} = 2'b11;

`else
// Memory card
assign {nCD1, nCD2} = {2{~MEMCARD_EN & ~SYSTEM_CDx}};	// Always plugged in CD systems
assign CARD_WE = (SYSTEM_CDx | (~nCARDWEN & CARDWENB)) & ~nCRDW;

wire [15:0] memcard_buff_dout;
memcard MEMCARD(
	.CLK(CLK_48M),
	.SYSTEM_CDx(SYSTEM_CDx),
	.CDA(CDA), .CDD(CDD),
	.CARD_WE(CARD_WE),
	.M68K_DATA(M68K_DATA[7:0]),

	.clk_sys(CLK_MEMCARD),
	.memcard_addr(MEMCARD_ADDR),
	.memcard_wr(MEMCARD_WR),
	.memcard_din(MEMCARD_DIN),
	.memcard_dout(MEMCARD_DOUT)
);
`endif

/*
// CA4's polarity depends on the tile's h-flip attribute
// Normal: CA4 high, then low
// Flipped: CA4 low, then high
*/
assign CROM_ADDR = {C_LATCH_EXT, C_LATCH, ~CA4, 2'b00}/* & CROM_MASK*/;
assign CROM_RD = PCK1 | PCK2;

zmc ZMC(
	.CLK(CLK_48M),
	.nRESET(nRESET & ~SYSTEM_CDx),
	.nSDRD0(SDRD0),
	.SDA_L(SDA[1:0]), .SDA_U(SDA[15:8]),
	.MA(MA)
);

// Bankswitching for the PORT zone, do all games use a 1MB window ?
// P_BANK stays at 0 for CD systems
always @(posedge CLK_48M)
begin
	reg nPORTWEL_d;
	nPORTWEL_d <= nPORTWEL;

	if (!nRESET)
		P_BANK <= 0;
	else if (nPORTWEL & ~nPORTWEL_d)
		if (!SYSTEM_CDx) P_BANK <= M68K_DATA[3:0];
end

// PRO-CT0 used as security chip
wire [3:0] GAD_SEC;
wire [3:0] GBD_SEC;

reg nPORTWEL_D;
always @(posedge CLK_48M) nPORTWEL_D <= nPORTWEL;

zmc2_dot ZMC2DOT(
	.CLK(CLK_48M),
	.CLK_EN_12M_N(nPORTWEL_D & ~nPORTWEL),
	.EVEN(M68K_ADDR[2]), .LOAD(M68K_ADDR[1]), .H(M68K_ADDR[3]),
	.CR({
		M68K_ADDR[19], M68K_ADDR[15], M68K_ADDR[18], M68K_ADDR[14],
		M68K_ADDR[17], M68K_ADDR[13], M68K_ADDR[16], M68K_ADDR[12],
		M68K_ADDR[11], M68K_ADDR[7], M68K_ADDR[10], M68K_ADDR[6],
		M68K_ADDR[9], M68K_ADDR[5], M68K_ADDR[8], M68K_ADDR[4],
		M68K_DATA[15], M68K_DATA[11], M68K_DATA[14], M68K_DATA[10],
		M68K_DATA[13], M68K_DATA[9], M68K_DATA[12], M68K_DATA[8],
		M68K_DATA[7], M68K_DATA[3], M68K_DATA[6], M68K_DATA[2],
		M68K_DATA[5], M68K_DATA[1], M68K_DATA[4], M68K_DATA[0]
		}),
	.GAD(GAD_SEC), .GBD(GBD_SEC)
);	

assign M68K_DATA[7:0] = ((CART_CHIP == 1) & ~nPORTOEL) ?
								{GBD_SEC[1], GBD_SEC[0], GBD_SEC[3], GBD_SEC[2],
								GAD_SEC[1], GAD_SEC[0], GAD_SEC[3], GAD_SEC[2]} : 8'bzzzzzzzz;

neo_273 NEO273(
	.CLK(CLK_48M),
	.PBUS(PBUS[19:0]),
	.PCK1B_EN(PCK1_EN_N), .PCK2B_EN(PCK2_EN_N),
	.C_LATCH(C_LATCH), .S_LATCH(S_LATCH)
);

// 4 MSBs not handled by NEO-273
always @(posedge CLK_48M) begin
	if (PCK1_EN_N) C_LATCH_EXT <= PBUS[23:20];
end

neo_cmc neo_cmc
(
	.CLK(CLK_48M),
	.PCK2B_EN(PCK2_EN_N),
	.PBUS(PBUS[14:0]),
	.TYPE(CMC_CHIP),
	.ADDR(FIXMAP_ADDR),
	.BANK(FIX_BANK)
);


// Fake COM MCU
wire [15:0] COM_DOUT;

com COM(
	.nRESET(nRESET),
	.CLK_48M(CLK_48M),
	.nPORTOEL(nPORTOEL), .nPORTOEU(nPORTOEU), .nPORTWEL(nPORTWEL),
	.M68K_DIN(COM_DOUT)
);

assign M68K_DATA = (CART_CHIP == 2) ? COM_DOUT : 16'bzzzzzzzz_zzzzzzzz;

syslatch SL(
	.nRESET(nRESET),
	.CLK(CLK_48M),
	.CLK_EN_68K_P(CLK_EN_68K_P),
	.M68K_ADDR(M68K_ADDR[4:1]),
	.nBITW1(nBITW1),
	.SHADOW(SHADOW), .nVEC(nVEC), .nCARDWEN(nCARDWEN),	.CARDWENB(CARDWENB), .nREGEN(nREGEN), .nSYSTEM(nSYSTEM), .nSRAMWEN(nSRAMWEN), .PALBNK(PALBNK)
);

wire nSRAMWEN_G = SYSTEM_MVS ? nSRAMWEN : 1'b1;	// nSRAMWEN is only for MVS
wire nSYSTEM_G = SYSTEM_MVS ? nSYSTEM : 1'b1;	// nSYSTEM is only for MVS
assign SYSTEM_ROMS = ~nSYSTEM_G;

neo_e0 E0(
	.M68K_ADDR(M68K_ADDR[23:1]),
	.BNK(BNK),
	.nSROMOEU(nSROMOEU),	.nSROMOEL(nSROMOEL), .nSROMOE(nSROMOE),
	.nVEC(nVEC),
	.A23Z(A23Z), .A22Z(A22Z),
	.CDA(CDA)
);

neo_f0 F0(
	.CLK(CLK_48M),
	.nRESET(nRESET),
	.nDIPRD0(nDIPRD0), .nDIPRD1(nDIPRD1),
	.nBITW0(nBITW0), .nBITWD0(nBITWD0),
	.DIPSW({~DIPSW[2:1], 5'b11111, ~DIPSW[0]}),
	.COIN1(~COIN1), .COIN2(~COIN2),
	.M68K_ADDR(M68K_ADDR[7:4]),
	.M68K_DATA(M68K_DATA[7:0]),
	.SYSTEMB(~nSYSTEM_G),
	.RTC_DOUT(RTC_DOUT), .RTC_TP(RTC_TP), .RTC_DIN(RTC_DIN), .RTC_CLK(RTC_CLK), .RTC_STROBE(RTC_STROBE),
	.SYSTEM_TYPE(SYSTEM_MVS)
);

uPD4990 RTCC(
	.rtc(RTC),
	.nRESET(nRESET),
	.CLK(CLK_48M),
	.CLK_EN_12M(CLK_EN_12M),
	.DATA_CLK(RTC_CLK), .STROBE(RTC_STROBE),
	.DATA_IN(RTC_DIN), .DATA_OUT(RTC_DOUT),
	.CS(1'b1), .OE(1'b1),
	.TP(RTC_TP)
);

neo_g0 G0(
	.M68K_DATA(M68K_DATA),
	.G0(nCRDC), .G1(nPAL), .DIR(M68K_RW), .WE(nPAL_WE),
	.CDD({8'hFF, CDD}), .PC(PAL_RAM_DATA)
);

neo_c1 C1(
	.CLK(CLK_48M),
	.M68K_ADDR(M68K_ADDR[21:17]),
	.M68K_DATA(M68K_DATA[15:8]), .A22Z(A22Z), .A23Z(A23Z),
	.nLDS(nLDS), .nUDS(nUDS), .RW(M68K_RW), .nAS(nAS),
	.nROMOEL(nROMOEL), .nROMOEU(nROMOEU),
	.nPORTOEL(nPORTOEL), .nPORTOEU(nPORTOEU), .nPORTWEL(nPORTWEL), .nPORTWEU(nPORTWEU),
	.nPORT_ZONE(nPORTADRS),
	.nWRL(nWRL), .nWRU(nWRU), .nWWL(nWWL), .nWWU(nWWU),
	.nSROMOEL(nSROMOEL), .nSROMOEU(nSROMOEU),
	.nSRAMOEL(nSRAMOEL), .nSRAMOEU(nSRAMOEU), .nSRAMWEL(nSRAMWEL), .nSRAMWEU(nSRAMWEU),
	.nLSPOE(nLSPOE), .nLSPWE(nLSPWE),
	.nCRDO(nCRDO), .nCRDW(nCRDW), .nCRDC(nCRDC),
	.nSDW(nSDW),
	.P1_IN(~P1_IN),
	.P2_IN(~P2_IN),
	.nCD1(nCD1), .nCD2(nCD2),
	.nWP(0),			// Memory card is never write-protected
	.nROMWAIT(~ROM_WAIT), .nPWAIT0(~P_WAIT[0]), .nPWAIT1(~P_WAIT[1]), .PDTACK(1),
	.SDD_WR(SDD_OUT),
	.SDD_RD(SDD_RD_C1),
	.nSDZ80R(nSDZ80R), .nSDZ80W(nSDZ80W), .nSDZ80CLR(nSDZ80CLR),
	.CLK_EN_68K_P(CLK_EN_68K_P),
	.nDTACK(nDTACK),
	.nBITW0(nBITW0), .nBITW1(nBITW1),
	.nDIPRD0(nDIPRD0), .nDIPRD1(nDIPRD1),
	.nPAL_ZONE(nPAL),
	.SYSTEM_TYPE(SYSTEM_TYPE)
);

wire [31:0] CR = CD_USE_SPR ? {32{1'bz}} : CROM_DATA;

neo_zmc2 ZMC2(
	.CLK(CLK_48M),
	.CLK_EN_12M_N(CLK_EN_12M_N),
	.EVEN(EVEN1), .LOAD(LOAD), .H(H),
	.CR(CR),
	.GAD(GAD), .GBD(GBD),
	.DOTA(DOTA), .DOTB(DOTB)
);

/*
dpram #(16) LO(

	.clock_a(clk_sys),
	.address_a(ioctl_addr[16:1]),
	.data_a(ioctl_dout[7:0]),
	.wren_a(ioctl_download & (ioctl_index == INDEX_LOROM) & ioctl_wr),

	.clock_b(CLK_24M),
	.address_b(PBUS[15:0]),
	.q_b(LO_ROM_DATA)
);
*/
// VCS is normally used as the LO ROM's nOE but the NeoGeo relies on the fact that the LO ROM
// will still have its output active for a short moment (~50ns) after nOE goes high
// nPBUS_OUT_EN is used internally by LSPC2 but it's broken out here to use the additional
// half mclk cycle it provides compared to VCS. This makes sure LO_ROM_DATA is valid when latched.
assign PBUS[23:16] = nPBUS_OUT_EN ? LO_ROM_DATA : 8'bzzzzzzzz;

spram #(11,16) UFV(
	.clock(CLK_48M),	//~CLK_24M,		// Is just CLK ok ?
	.address(FAST_VRAM_ADDR),
	.data(FAST_VRAM_DATA_OUT),
	.wren(~CWE),
	.q(FAST_VRAM_DATA_IN)
);

`ifdef VRAM32
// fixmap only
spram #(12,16) USV(
	.clock(CLK_48M),
	.address(SLOW_VRAM_ADDR[11:0]),
	.data(SLOW_VRAM_DATA_OUT),
	.wren(~BWE & ~SCB1_CS),
	.q(SLOW_FIX_VRAM_DATA_IN)
);
`else
spram #(15,16) USV(
	.clock(CLK_48M),
	.address(SLOW_VRAM_ADDR),
	.data(SLOW_VRAM_DATA_OUT),
	.wren(~BWE),
	.q(SLOW_VRAM_DATA_IN)
);
`endif

wire [18:11] MA;
wire [7:0] Z80_RAM_DATA;

spram #(11) Z80RAM(.clock(CLK_48M), .address(SDA[10:0]), .data(SDD_OUT), .wren(~(nZRAMCS | nSDMWR)), .q(Z80_RAM_DATA));	// Fast enough ?

assign SDD_IN = (~nSDZ80R) ? SDD_RD_C1 :
					(~nSDMRD & ~nZRAMCS) ? Z80_RAM_DATA :
					(~nSDMRD & (~nSDROM | SYSTEM_CDx)) ? M1_ROM_DATA :
					(~n2610CS & ~n2610RD) ? YM2610_DOUT :
					8'b00000000;

wire Z80_nRESET = SYSTEM_CDx ? nRESET & CD_nRESET_Z80 : nRESET;
wire CD_HAS_Z80_BUS = (CD_USE_Z80 & ~(nBUSAK & Z80_nRESET));

reg Z80_ROM_WR_PRE; // data out valid, but nWR is not asserted yet
always @(posedge CLK_48M) if (CLK_EN_4M_P) Z80_ROM_WR_PRE <= ~CD_HAS_Z80_BUS & ~nZ80_MREQ & nZ80_SDRD;

wire [7:0] M1_ROM_DATA = Z80_ROM_DATA;
assign Z80_ROM_RD = ~(nSDMRD | (nSDROM & ~SYSTEM_CDx) | ~nZRAMCS);
assign Z80_ROM_WR = (~nSDMWR | Z80_ROM_WR_PRE) & nZRAMCS & SYSTEM_CDx; // in CD mode, the full Z80 area is writeable
assign Z80_ROM_ADDR = {~SYSTEM_CDx ? MA : SDA[15:11], SDA[10:0]};
assign Z80_ROM_DOUT = SDD_OUT;
wire nZ80WAIT = (Z80_ROM_RD | Z80_ROM_WR) ? Z80_ROM_READY : 1'b1;

cpu_z80 Z80CPU(
	.CLK(CLK_48M),
	.CLK4P_EN(CLK_EN_4M_P),
	.CLK4N_EN(CLK_EN_4M_N),
	.nRESET(Z80_nRESET),
	.SDA(Z80_SDA), .SDD_IN(SDD_IN), .SDD_OUT(Z80_SDD_OUT),
	.nIORQ(nIORQ),	.nMREQ(nZ80_MREQ),	.nRD(nZ80_SDRD), .nWR(nZ80_SDWR),
	.nBUSRQ(~CD_USE_Z80), .nBUSAK(nBUSAK),
	.nINT(nZ80INT), .nNMI(nZ80NMI), .nWAIT(nZ80WAIT)
);

assign { SDA, SDD_OUT } = ~CD_HAS_Z80_BUS ? { Z80_SDA, Z80_SDD_OUT } : DMA_RUNNING ? { DMA_ADDR_OUT[16:1], DMA_DATA_OUT[7:0] } : { M68K_ADDR[16:1], M68K_DATA[7:0] };
assign { nSDRD, nSDWR } = ~CD_HAS_Z80_BUS ? { nZ80_SDRD, nZ80_SDWR } : { ~CD_TR_RD_Z80, ~CD_TR_WR_Z80 };
assign { nMREQ } = ~CD_HAS_Z80_BUS ? nZ80_MREQ : ~(CD_TR_RD_Z80 | CD_TR_WR_Z80);

assign M68K_DATA[7:0] = ~(CD_HAS_Z80_BUS & CD_TR_RD_Z80) ? 8'bzzzz_zzzz : (SDD_IN);

wire [7:0] YM2610_DOUT;
assign ADPCMA_RD = ~nSDROE;
assign ADPCMB_RD = ~nSDPOE & ~SYSTEM_CDx;

jt10 YM2610(
	.rst(~Z80_nRESET),
	.clk(CLK_48M), .cen((CLK_EN_4M_P | CLK_EN_4M_N) & ADPCMA_DATA_READY & ADPCMB_DATA_READY),
	.addr(SDA[1:0]),
	.din(SDD_OUT), .dout(YM2610_DOUT),
	.cs_n(n2610CS), .wr_n(n2610WR),
	.irq_n(nZ80INT),
	.adpcma_addr(ADPCMA_ADDR), .adpcma_bank(ADPCMA_BANK), .adpcma_roe_n(nSDROE), .adpcma_data(ADPCMA_DATA),
	.adpcmb_addr(ADPCMB_ADDR), .adpcmb_roe_n(nSDPOE), .adpcmb_data(SYSTEM_CDx ? 8'h08 : ADPCMB_DATA),	// CD has no ADPCM-B
	.snd_right(snd_right), .snd_left(snd_left), .ch_enable(6'b111111)
);

// For Neo CD only
wire VIDEO_EN = SYSTEM_CDx ? CD_VIDEO_EN : 1'b1;
wire FIX_EN = DBG_FIX_EN & (SYSTEM_CDx ? CD_FIX_EN : 1'b1);
wire SPR_EN = DBG_SPR_EN & (SYSTEM_CDx ? CD_SPR_EN : 1'b1);
wire DOTA_GATED = SPR_EN & DOTA;
wire DOTB_GATED = SPR_EN & DOTB;

lspc2_a2_sync	LSPC(
	.CLK(CLK_48M),
	.CLK_EN_24M_P(CLK_EN_24M_P),
	.CLK_EN_24M_N(CLK_EN_24M_N),
	.RESET(nRESET),
	.nRESETP(nRESETP),
	.LSPC_8M(), .LSPC_4M(),
	.LSPC_EN_4M_P(CLK_EN_4M_P), .LSPC_EN_4M_N(CLK_EN_4M_N),
	.M68K_ADDR(M68K_ADDR[3:1]), .M68K_DATA(M68K_DATA),
	.IPL0(IPL0), .IPL1(IPL1),
	.CD_VBLANK_IRQ_EN(CD_VBLANK_IRQ_EN | ~SYSTEM_CDx),
	.CD_TIMER_IRQ_EN(CD_TIMER_IRQ_EN | ~SYSTEM_CDx),
	.LSPOE(nLSPOE), .LSPWE(nLSPWE),
	.PBUS_OUT(PBUS[15:0]), .PBUS_IO(PBUS[23:16]),
	.nPBUS_OUT_EN(nPBUS_OUT_EN),
	.DOTA(DOTA_GATED), .DOTB(DOTB_GATED),
	.CA4(CA4), .S2H1(S2H1), .S1H1(S1H1),
	.LOAD(LOAD), .H(H), .EVEN1(EVEN1), .EVEN2(EVEN2),
	.PCK1(PCK1), .PCK2(PCK2),
	.PCK1_EN_N(PCK1_EN_N), .PCK2_EN_N(PCK2_EN_N),
	.PCK1_EN_P(PCK1_EN_P), .PCK2_EN_P(PCK2_EN_P),
	.CHG(CHG),
	.LD1(LD1), .LD2(LD2),
	.WE(WE), .CK(CK),	.SS1(SS1), .SS2(SS2),
	.HSYNC(HSYNC), .VSYNC(VSYNC),
	.CHBL(CHBL), .BNKB(nBNKB),
	.VCS(VCS),
	.SVRAM_ADDR(SLOW_VRAM_ADDR),
	.SVRAM_DATA_IN(SLOW_VRAM_DATA_IN), .SVRAM_DATA_OUT(SLOW_VRAM_DATA_OUT),
	.BOE(BOE), .BWE(BWE),
	.FVRAM_ADDR(FAST_VRAM_ADDR),
	.FVRAM_DATA_IN(FAST_VRAM_DATA_IN), .FVRAM_DATA_OUT(FAST_VRAM_DATA_OUT),
	.CWE(CWE),
	.VMODE(VIDEO_MODE),
	.FIXMAP_ADDR(FIXMAP_ADDR),	// Extracted for NEO-CMC
	.SPRMAP_ADDR(SPRMAP_ADDR),
	.VRAM_ADDR(CPU_VRAM_ADDR),
	.VRAM_CYCLE(VRAM_CYCLE),
	.SVRAM_WR(SLOW_VRAM_WR),
	.LO_ROM_ADDR(LO_ROM_ADDR)
);

wire nRESET_WD;
wire DOGE = SYSTEM_CDx ? ~CD_UPLOAD_EN : 1'b1; // UPLOAD_EN disables Watchdog?

neo_b1 B1(
	.CLK(CLK_48M),	.CLK_EN_6MB(CLK_EN_6MB), .CLK_EN_1HB(CLK_EN_1HB),
	.S1H1(S1H1),
	.A23I(A23Z), .A22I(A22Z),
	.M68K_ADDR_U(M68K_ADDR[21:17]), .M68K_ADDR_L(M68K_ADDR[12:1]),
	.nLDS(nLDS), .RW(M68K_RW), .nAS(nAS),
	.PBUS(PBUS),
	.FIXD(FIXD),
	.PCK1_EN(PCK1_EN_P), .PCK2_EN(PCK2_EN_P),
	.CHBL(CHBL), .BNKB(nBNKB),
	.GAD(GAD), .GBD(GBD),
	.WE(WE), .CK(CK),
	.TMS0(CHG), .LD1(LD1), .LD2(LD2), .SS1(SS1), .SS2(SS2),
	.PA(PAL_RAM_ADDR),
	.EN_FIX(FIX_EN),
	.DOGE(DOGE),
	.nRST(nRESET),
	.nRESET(nRESET_WD)
);

spram #(13,16) PALRAM(
	.clock(CLK_48M), 	// Was CLK_12M
	.address({PALBNK, PAL_RAM_ADDR}),
	.data(M68K_DATA),
	.wren(~nPAL_WE),
	.q(PAL_RAM_DATA)
);

wire [6:0] R6 = {1'b0, PAL_RAM_DATA[11:8], PAL_RAM_DATA[14], PAL_RAM_DATA[11]} - PAL_RAM_DATA[15];
wire [6:0] G6 = {1'b0, PAL_RAM_DATA[7:4],  PAL_RAM_DATA[13], PAL_RAM_DATA[7] } - PAL_RAM_DATA[15];
wire [6:0] B6 = {1'b0, PAL_RAM_DATA[3:0],  PAL_RAM_DATA[12], PAL_RAM_DATA[3] } - PAL_RAM_DATA[15];

wire [7:0] R8 = R6[6] ? 8'd0 : {R6[5:0],  R6[4:3]};
wire [7:0] G8 = G6[6] ? 8'd0 : {G6[5:0],  G6[4:3]};
wire [7:0] B8 = B6[6] ? 8'd0 : {B6[5:0],  B6[4:3]};

always @(posedge CLK_48M) begin
	reg CHBL2;
	if (CLK_EN_6MB) begin
		RED   <= VIDEO_EN ? (~SHADOW ? R8 : {1'b0, R8[7:1]}) : 8'd0;
		GREEN <= VIDEO_EN ? (~SHADOW ? G8 : {1'b0, G8[7:1]}) : 8'd0;
		BLUE  <= VIDEO_EN ? (~SHADOW ? B8 : {1'b0, B8[7:1]}) : 8'd0;
		CHBL2 <= CHBL;
		HBLANK <= CHBL2;
		VBLANK <= ~nBNKB;
	end
end
assign CE_PIXEL = CLK_EN_6MB;

endmodule
