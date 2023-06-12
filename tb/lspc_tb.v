// ====================================================================
//
//  Neo-Geo LSPC testbench
//
//  Copyright (C) 2023 Gyorgy Szombathelyi <gyurco@freemail.hu>
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
//
//============================================================================

module lspc_tb (
	input CLK_48M,
	input nRESET,
	input VIDEO_MODE,

	// CPU bus
	output CLK_EN_68K_P,
	output CLK_EN_68K_N,
	input  FC0,
	input  FC1,
	input  FC2,
	input  nAS,
	input  M68K_RW,
	input  nUDS,
	input  nLDS,
	input  [23:1] M68K_ADDR,
	input  [15:0] M68K_DATA,
	output nHALT,
	output IPL0,
	output IPL1,

	output [7:0] RED,
	output [7:0] GREEN,
	output [7:0] BLUE,
	output HSYNC,
	output VSYNC,

	output [26:0] CROM_ADDR,
	input  [63:0] CR_DOUBLE,

	output [17:0] SFIX_ADDR,
	input  [15:0] SFIX_DATA,

	output [15:0] LO_ROM_ADDR,
	input   [7:0] LO_ROM_DATA,

	output [11:0] PAL_RAM_ADDR,
	input  [15:0] PAL_RAM_DATA,

	output [10:0] FAST_VRAM_ADDR,
	input  [15:0] FAST_VRAM_DATA_IN,
	output [15:0] FAST_VRAM_DATA_OUT,
	output        CWE,

	output [14:0] SLOW_VRAM_ADDR,
	input [31: 0] SLOW_VRAM_DATA_IN,
	output[15: 0] SLOW_VRAM_DATA_OUT,
	output        BOE,
	output        BWE

);

reg          CLK_24M = 1;
initial begin
	assign CLK_24M = 1;
end

always @(posedge CLK_48M) CLK_24M <= ~CLK_24M;

wire         SP_EN = 1'b1;
wire         FIX_EN = 1'b1;

wire         A22Z = 1'b0;
wire         A23Z = 1'b0;
wire         SHADOW = 1'b0;

wire [ 1: 0] FIX_BANK = 0;

wire [23: 0] PBUS;
wire         nLSPOE, nLSPWE;
wire         DOTA, DOTB;
wire         DOTA_GATED, DOTB_GATED;
wire         CA4;
wire         S2H1;
wire         S1H1;
wire         LOAD;
wire         H;
wire         EVEN1;					// For ZMC2
wire         EVEN2;
wire         CHG;					// Also called TMS0
wire         LD1, LD2;					// Buffer address load
wire         PCK1, PCK2;
wire         PCK1_EN_N, PCK2_EN_N;
wire         PCK1_EN_P, PCK2_EN_P;
wire [ 3: 0] WE;
wire [ 3: 0] CK;
wire         SS1, SS2;					// Buffer pair selection for B1
wire         nRESETP;
wire         CHBL;
wire         nBNKB;
wire         VCS;					// LO ROM output enable
wire         CLK_8M;
wire         CLK_4M;


wire         nPBUS_OUT_EN;

wire [14: 0] FIXMAP_ADDR;		// Extracted for NEO-CMC
wire [14: 0] SPRMAP_ADDR;
wire [15: 0] CPU_VRAM_ADDR;        // CPU access address
wire [ 1: 0] VRAM_CYCLE;
wire [ 7: 0] FIXD;

wire A23Z, A22Z, nIO_ZONE, nLSPC_ZONE;
wire nVEC = 0;

assign {A23Z, A22Z} = M68K_ADDR[23:22] ^ {2{~|{M68K_ADDR[21:7], ^M68K_ADDR[23:22], nVEC}}};
assign nIO_ZONE = |{A23Z, A22Z, ~M68K_ADDR[21], ~M68K_ADDR[20]};
assign nLSPC_ZONE = |{nIO_ZONE, ~M68K_ADDR[19], ~M68K_ADDR[18], M68K_ADDR[17]};
assign nLSPWE = M68K_RW | nUDS | nLSPC_ZONE;
assign nLSPOE = ~M68K_RW | nUDS | nLSPC_ZONE;

assign DOTA_GATED = SP_EN & DOTA;
assign DOTB_GATED = SP_EN & DOTB;

assign PBUS[23:16] = nPBUS_OUT_EN ? LO_ROM_DATA : 8'bzzzzzzzz;

wire [15:0] LSPC_M68K_DATA = nLSPOE ? M68K_DATA : 16'hZZZZ;

lspc2_a2_sync	LSPC_sync(
//lspc2_a2	LSPC(
	.CLK(CLK_48M),
	.CLK_EN_24M_P(~CLK_24M),
	.CLK_EN_24M_N( CLK_24M),
//	.CLK_24M(CLK_24M),
	.RESET(nRESET),
	.nRESETP(nRESETP),
	.LSPC_8M(CLK_8M), .LSPC_4M(CLK_4M),
	.LSPC_EN_4M_P(), .LSPC_EN_4M_N(),
	.M68K_ADDR(M68K_ADDR[3:1]), .M68K_DATA(LSPC_M68K_DATA),
	.IPL0(IPL0), .IPL1(IPL1),
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
	.WE(WE), .CK(CK), .SS1(SS1), .SS2(SS2),
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
	.SVRAM_WR(),
	.LO_ROM_ADDR(LO_ROM_ADDR)
);

//lspc2_a2_sync	LSPC_sync(
lspc2_a2	LSPC(
//	.CLK(CLK_48M),
//	.CLK_EN_24M_P(~CLK_24M),
//	.CLK_EN_24M_N( CLK_24M),
	.CLK_24M(CLK_24M),
	.RESET(nRESET),
	.nRESETP(),
	.LSPC_8M(), .LSPC_4M(),
	.M68K_ADDR(M68K_ADDR[3:1]), .M68K_DATA(LSPC_M68K_DATA),
	.IPL0(), .IPL1(),
	.LSPOE(nLSPOE), .LSPWE(nLSPWE),
	.PBUS_OUT(PBUS[15:0]), .PBUS_IO(PBUS[23:16]),
	.nPBUS_OUT_EN(),
	.DOTA(DOTA_GATED), .DOTB(DOTB_GATED),
	.CA4(), .S2H1(), .S1H1(),
	.LOAD(), .H(), .EVEN1(), .EVEN2(),
	.PCK1(), .PCK2(),
	.CHG(),
	.LD1(), .LD2(),
	.WE(), .CK(), .SS1(), .SS2(),
	.HSYNC(), .VSYNC(),
	.CHBL(), .BNKB(),
	.VCS(),
	.SVRAM_ADDR(),
	.SVRAM_DATA_IN(SLOW_VRAM_DATA_IN), .SVRAM_DATA_OUT(),
	.BOE(), .BWE(),
	.FVRAM_ADDR(),
	.FVRAM_DATA_IN(FAST_VRAM_DATA_IN), .FVRAM_DATA_OUT(),
	.CWE(),
	.VMODE(VIDEO_MODE),
	.FIXMAP_ADDR(),	// Extracted for NEO-CMC
	.SPRMAP_ADDR(),
	.VRAM_ADDR(),
	.VRAM_CYCLE(),
	.LO_ROM_ADDR()
);

wire         CLK_12M, CLK_EN_12M, CLK_EN_12M_N, CLK_68KCLK, CLK_68KCLKB, CLK_6MB, CLK_1HB, CLK_EN_6MB, CLK_EN_1HB;

clocks CLK(CLK_24M, nRESETP, , , , , );
clocks_sync CLK_SYNC(CLK_48M, ~CLK_24M, CLK_24M, nRESETP, , CLK_12M, CLK_68KCLK, CLK_68KCLKB, CLK_EN_68K_P, CLK_EN_68K_N, CLK_6MB, CLK_1HB, CLK_EN_12M, CLK_EN_12M_N, CLK_EN_6MB, CLK_EN_1HB);

wire [19:0] C_LATCH;
reg   [3:0] C_LATCH_EXT;
wire [15:0] S_LATCH;

neo_273 NEO273(
	.CLK(CLK_48M),
	.PBUS(PBUS[19:0]),
	.PCK1B_EN(PCK1_EN_N), .PCK2B_EN(PCK2_EN_N),
	.C_LATCH(C_LATCH), .S_LATCH(S_LATCH)
);


// 4 MSBs not handled by NEO-273
//always @(negedge PCK1)
//	C_LATCH_EXT <= PBUS[23:20];
always @(posedge CLK_48M) begin
	reg PCK1_D;
	if (PCK1_EN_N) C_LATCH_EXT <= PBUS[23:20];
end

assign CROM_ADDR = {C_LATCH_EXT, C_LATCH, 3'b000};// & CROM_MASK;

wire [ 3: 0] GAD;
wire [ 3: 0] GBD;

// This is used to split burst-read sprite gfx data in half at the right time
reg LOAD_SR;
reg CA4_REG;
/*
// CA4's polarity depends on the tile's h-flip attribute
// Normal: CA4 high, then low
// Flipped: CA4 low, then high
always @(negedge CLK_24M) if (LOAD_EN) CA4_REG <= CA4;

// CR_DOUBLE: [8px left] [8px right]
//         BP  A B C D    A B C D
wire [31:0] CR = CA4_REG ? CR_DOUBLE[63:32] : CR_DOUBLE[31:0];

neo_zmc2 ZMC2(
	.CLK(CLK_24M),
	.CLK_EN_12M_N(CLK_12M),
	.EVEN(EVEN1), .LOAD_EN(LOAD_EN), .H(H),
	.CR(CR),
	.GAD(GAD), .GBD(GBD),
	.DOTA(DOTA), .DOTB(DOTB)
);

*/
// CA4's polarity depends on the tile's h-flip attribute
// Normal: CA4 high, then low
// Flipped: CA4 low, then high
always @(posedge CLK_24M) begin
	LOAD_SR <= LOAD;
	if (~LOAD_SR & LOAD) CA4_REG <= CA4;
end

// CR_DOUBLE: [8px left] [8px right]
//         BP  A B C D    A B C D

wire [31:0] CR = ~CA4_REG ? CR_DOUBLE[63:32] : CR_DOUBLE[31:0];

neo_zmc2 ZMC2(
	.CLK(CLK_48M),
	.CLK_EN_12M(CLK_EN_12M_N),
	.EVEN(EVEN1), .LOAD(LOAD), .H(H),
	.CR(CR),
	.GAD(GAD), .GBD(GBD),
	.DOTA(DOTA), .DOTB(DOTB)
);

wire [15:0] SROM_DATA = SFIX_DATA;
assign SFIX_ADDR = {FIX_BANK, S_LATCH[15:4], S_LATCH[2:0], ~S_LATCH[3]};

assign FIXD = S2H1 ? SROM_DATA[15:8] : SROM_DATA[7:0];

wire nRESET_WD;
neo_b1 B1(
	.CLK(CLK_48M),	.CLK_EN_6MB(CLK_EN_6MB), .CLK_EN_1HB(CLK_EN_1HB),
	.S1H1(S1H1),
	.A23I(A23Z), .A22I(A22Z),
	.M68K_ADDR_U(M68K_ADDR[21:17]), .M68K_ADDR_L(M68K_ADDR[12:1]),
	.nHALT(nHALT), .nLDS(nLDS), .RW(M68K_RW), .nAS(nAS),
	.PBUS(PBUS),
	.FIXD(FIXD),
	.PCK1_EN(PCK1_EN_P), .PCK2_EN(PCK2_EN_P),
	.CHBL(CHBL), .BNKB(nBNKB),
	.GAD(GAD), .GBD(GBD),
	.WE(WE), .CK(CK),
	.TMS0(CHG), .LD1(LD1), .LD2(LD2), .SS1(SS1), .SS2(SS2),
	.PA(PAL_RAM_ADDR),
	.EN_FIX(FIX_EN),
	.nRST(nRESET),
	.nRESET(nRESET_WD)
);

wire [6:0] R6 = {1'b0, PAL_RAM_DATA[11:8], PAL_RAM_DATA[14], PAL_RAM_DATA[11]} - {6'd0, PAL_RAM_DATA[15]};
wire [6:0] G6 = {1'b0, PAL_RAM_DATA[7:4],  PAL_RAM_DATA[13], PAL_RAM_DATA[7] } - {6'd0, PAL_RAM_DATA[15]};
wire [6:0] B6 = {1'b0, PAL_RAM_DATA[3:0],  PAL_RAM_DATA[12], PAL_RAM_DATA[3] } - {6'd0, PAL_RAM_DATA[15]};

wire [7:0] R8 = R6[6] ? 8'd0 : {R6[5:0],  R6[4:3]};
wire [7:0] G8 = G6[6] ? 8'd0 : {G6[5:0],  G6[4:3]};
wire [7:0] B8 = B6[6] ? 8'd0 : {B6[5:0],  B6[4:3]};

assign RED   = ~SHADOW ? R8 : {1'b0, R8[7:1]};
assign GREEN = ~SHADOW ? G8 : {1'b0, G8[7:1]};
assign BLUE  = ~SHADOW ? B8 : {1'b0, B8[7:1]};

endmodule;
