module NeoGeo_MiST(
	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        AUDIO_L,
	output        AUDIO_R,
	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,
	input         SPI_SS3,
	input         CONF_DATA0,
	input         CLOCK_27,

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`else
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif

	input         UART_RX,
	output        UART_TX

);

`ifdef NO_DIRECT_UPLOAD
localparam DIRECT_UPLOAD = 0;
`else
localparam DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`include "build_id.v" 

wire [6:0] core_mod;

//`define DEBUG 1

localparam CONF_STR = {
	"NEOGEO;;",
	"F,NEO,Load Cart;",
	"F,NEO,Load Cart (skip ADPCM);",
	"F,ROM,Load BIOS;",
	"S0U,SAV,Load Memory Card;",
	"TG,Save Memory Card;",
	"SC,CUE,Mount CD;",
	"O12,System Type,Console(AES),Arcade(MVS),CD,CDZ;",

`ifdef CARTOPTS
	"P1,Cart options;",
	"P1OMO,Protection,Off,NEO-ZMC2,NEO-PVC,KOF99,GAROU,GAROUH,MSLUG3,KOF2000;",
	"P1OP,PRO-CT0,Off,On;",
	"P1OQ,Link-MCU,Off,On;",
	"P1ORS,NEO-CMC,Off,Type-1,Type-2;",
	"P1OT,ROMWait,Full speed,1 cycle;",
	"P1OUV,PWait,Full speed,1 cycle,2 cycles;",
`endif

	"OKL,CD Speed,1x,2x,3x,4x;",
	"OHI,CD Region,US,EU,JP,AS;",
	"OJ,CD Lid,Closed,Opened;",
	"O3,Video Mode,NTSC,PAL;",
	"O45,Scanlines,Off,25%,50%,75%;",
	"O7,Blending,Off,On;",
	"O6,Swap Joystick,Off,On;",
	"OB,Input,Joystick,Mouse;",
	"O8,[DIP] Settings,OFF,ON;",
	"O9,[DIP] Freeplay,OFF,ON;",
	"OA,[DIP] Freeze,OFF,ON;",
`ifdef DEBUG
	"OE,FIX Layer,ON,OFF;",
	"OF,Sprite Layer,ON,OFF;",
`endif
	"T0,Reset;",
	"V,v1.0.",`BUILD_DATE
};

wire  [1:0] scanlines = status[5:4];
wire        joyswap   = status[6];
wire        blend     = status[7];
wire  [1:0] orientation = 2'b00;
wire        rotate = 1'b0;
wire        oneplayer = 1'b0;
wire  [2:0] dipsw = status[10:8];
wire  [1:0] systype = status[2:1];
wire        vmode = status[3];
wire        bk_save = status[16];
wire        mouse_en = status[11];
wire  [1:0] cd_speed = status[21:20];
wire  [1:0] cd_region = status[18:17];
wire        cd_lid = ~status[19];

`ifdef CARTOPTS
wire  [2:0] pchip = status[24:22];
wire        proct0 = status[25];
wire        linkmcu = status[26];
wire  [1:0] cmcchip = status[28:27];
wire        romwait = status[29];
wire  [1:0] pwait = status[31:30];
`endif

wire        fix_en = ~status[14];
wire        spr_en = ~status[15];

assign LED = ~ioctl_downl;
assign SDRAM_CKE = 1; 
assign SDRAM_CLK = CLK_96M;

wire CLK_96M, CLK_48M;
wire pll_locked;
pll_mist pll(
	.inclk0(CLOCK_27),
//	.c0(SDRAM_CLK),
	.c0(CLK_96M),
//	.c1(CLK_96M),
	.c2(CLK_48M),
	.locked(pll_locked)
	);

wire [31:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire [15:0] joystick_0;
wire [15:0] joystick_1;
wire [63:0] rtc;
wire        scandoublerD;
wire        ypbpr;
wire        no_csync;
wire        key_pressed;
wire  [7:0] key_code;
wire        key_strobe;
wire signed [8:0] mouse_x;
wire signed [8:0] mouse_y;
wire        mouse_strobe;
wire  [7:0] mouse_flags;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_buff_rd;
wire  [1:0] img_mounted;
wire [31:0] img_size;

user_io #(
	.STRLEN(($size(CONF_STR)>>3)),
	.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD),
	.FEATURES(32'h8 | (QSPI << 2)) /* Neo-Geo CD, QSPI (optionally) */
	)
user_io(
	.clk_sys        (CLK_48M        ),
	.conf_str       (CONF_STR       ),
	.SPI_CLK        (SPI_SCK        ),
	.SPI_SS_IO      (CONF_DATA0     ),
	.SPI_MISO       (SPI_DO         ),
	.SPI_MOSI       (SPI_DI         ),
	.buttons        (buttons        ),
	.switches       (switches       ),
	.scandoubler_disable (scandoublerD	  ),
	.ypbpr          (ypbpr          ),
	.no_csync       (no_csync       ),
	.rtc            (rtc            ),
	.core_mod       (core_mod       ),
	.key_strobe     (key_strobe     ),
	.key_pressed    (key_pressed    ),
	.key_code       (key_code       ),
	.joystick_0     (joystick_0     ),
	.joystick_1     (joystick_1     ),
	.mouse_x        (mouse_x        ),
	.mouse_y        (mouse_y        ),
	.mouse_strobe   (mouse_strobe   ),
	.mouse_flags    (mouse_flags    ),
	.status         (status         ),

	.clk_sd         (CLK_48M        ),
	.sd_conf        (1'b0           ),
	.sd_sdhc        (1'b1           ),
	.sd_lba         (sd_lba         ),
	.sd_rd          (sd_rd          ),
	.sd_wr          (sd_wr          ),
	.sd_ack         (sd_ack         ),
	.sd_buff_addr   (sd_buff_addr   ),
	.sd_dout        (sd_buff_dout   ),
	.sd_din         (sd_buff_din    ),
	.sd_dout_strobe (sd_buff_wr     ),
	.sd_din_strobe  (sd_buff_rd     ),
	.img_mounted    (img_mounted    ),
	.img_size       (img_size       )
	);

wire        ioctl_downl;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_dout;

data_io #(.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD), .USE_QSPI(QSPI)) data_io(
	.clk_sys       ( CLK_96M      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
`ifdef USE_QSPI
	.QSCK          ( QSCK         ),
	.QCSn          ( QCSn         ),
	.QDAT          ( QDAT         ),
`endif
`ifdef NO_DIRECT_UPLOAD
	.SPI_SS4       ( 1'b1         ),
`else
	.SPI_SS4       ( SPI_SS4      ),
`endif
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.clkref_n      ( 1'b0         ),
	.ioctl_download( ioctl_downl  ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_dout    ( ioctl_dout   )
);

// reset signal generation
reg reset;
always @(posedge CLK_96M, negedge pll_locked) begin
	reg [15:0] reset_count;
	if (!pll_locked) begin
		reset <= 1;
		reset_count <= 16'hffff;
	end else begin
		if (status[0] | buttons[1] | ioctl_downl) reset_count <= 16'hffff;
		else if (reset_count != 0) reset_count <= reset_count - 1'd1;

		reset <= reset_count != 16'h0000;
	end
end

wire        CD_DATA_DOWNLOAD;
wire        CD_DATA_WR;
wire        CD_DATA_WR_READY;
wire        CDDA_WR;
wire        CDDA_WR_READY;
wire [15:0] CD_DATA_DIN;
wire [11:1] CD_DATA_ADDR;
wire [39:0] CDD_STATUS_IN;
wire        CDD_STATUS_LATCH;
wire [39:0] CDD_COMMAND_DATA;
wire        CDD_COMMAND_SEND;
wire [15:0] CD_AUDIO_L;
wire [15:0] CD_AUDIO_R;

data_io_neogeo data_io_neogeo(
	.clk_sys       ( CLK_48M      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.reset         ( reset        ),

	.CD_SPEED         ( cd_speed ),
	.CDD_STATUS_IN    ( CDD_STATUS_IN ),
	.CDD_STATUS_LATCH ( CDD_STATUS_LATCH ),
	.CDD_COMMAND_DATA ( CDD_COMMAND_DATA ),
	.CDD_COMMAND_SEND ( CDD_COMMAND_SEND ),
	.CD_DATA_DOWNLOAD ( CD_DATA_DOWNLOAD ),
	.CD_DATA_WR       ( CD_DATA_WR ),
	.CD_DATA_DIN      ( CD_DATA_DIN ),
	.CD_DATA_ADDR     ( CD_DATA_ADDR ),
	.CD_DATA_WR_READY ( CD_DATA_WR_READY ),
	.CDDA_WR          ( CDDA_WR ),
	.CDDA_WR_READY    ( CDDA_WR_READY )
);


wire        SYSTEM_ROMS;

wire [23:0] P2ROM_ADDR;
wire [15:0] PROM_DATA;
wire [15:0] PROM_DOUT;
wire  [1:0] PROM_DS;
wire        PROM_DATA_READY;
wire        ROM_RD;
wire        PORT_RD;
wire        SROM_RD;
wire        WRAM_WE;
wire        WRAM_RD;
wire        SRAM_WE;
wire        SRAM_RD;
wire        CD_EXT_RD;
wire        CD_EXT_WR;
wire        CD_FIX_RD;
wire        CD_FIX_WR;
wire        CD_SPR_RD;
wire        CD_SPR_WR;
wire        CD_PCM_RD;
wire        CD_PCM_WR;
wire [15:0] SP_PCM_Q;
reg         SP_PCM_READY;

reg         sdr_vram_req;
wire        sdr_vram_ack;
reg  [14:0] sdr_vram_addr;
reg         sdr_vram_we;
reg  [15:0] sdr_vram_d;
reg         sdr_vram_sel;

wire [14:0] SLOW_VRAM_ADDR;
wire [15:0] SLOW_VRAM_DATA_IN = SLOW_VRAM_DATA_IN_CPU;
wire [31:0] SLOW_VRAM_DATA_IN_SPR;
wire [15:0] SLOW_VRAM_DATA_IN_CPU;
wire [15:0] SLOW_VRAM_DATA_OUT;
wire        SLOW_VRAM_RD;
wire        SLOW_VRAM_WE;

wire [14:0] SPRMAP_ADDR;
wire        SPRMAP_RD;
wire [31:0] SPRMAP_DATA = SLOW_VRAM_DATA_IN_SPR;

wire [17:0] SFIX_ADDR;
wire [15:0] SFIX_DATA;
wire        SFIX_RD;

reg         lo_rom_req;
wire        LO_ROM_RD;
wire [15:0] LO_ROM_ADDR;
wire [15:0] LO_ROM_DATA;

reg         sp_req;
wire [26:0] CROM_ADDR;
wire        CROM_RD;
wire [31:0] CROM_DATA;
wire [31:0] CROM_DATA1;
`ifdef DUAL_SDRAM
wire [31:0] CROM_DATA2;
assign      CROM_DATA = systype[1] ? CROM_DATA1 : CROM_DATA2;
`else
assign      CROM_DATA = CROM_DATA1;
`endif

wire [18:0] Z80_ROM_ADDR;
wire        Z80_ROM_RD;
wire        Z80_ROM_WR;
wire [15:0] Z80_ROM_DATA;
wire  [7:0] Z80_ROM_DOUT;
wire        Z80_ROM_READY;

wire [19:0] ADPCMA_ADDR;
wire  [3:0] ADPCMA_BANK;
wire        ADPCMA_RD;
reg   [7:0] ADPCMA_DATA;
wire        ADPCMA_DATA_READY;
wire [23:0] ADPCMB_ADDR;
wire        ADPCMB_RD;
reg   [7:0] ADPCMB_DATA;
wire        ADPCMB_DATA_READY;

reg         sample_roma_req;
wire        sample_roma_ack;
wire [25:0] sample_roma_addr;
wire [31:0] sample_roma_dout;
reg         sample_romb_req;
wire        sample_romb_ack;
wire [25:0] sample_romb_addr;
wire [31:0] sample_romb_dout;

function [5:0] ceil_bit;
	input [31:0] value;
	integer i, bits;
	begin
		ceil_bit = 0;
		bits = 0;
		for (i = 0; i < 31; i = i + 1)
			if (value[i]) begin
				ceil_bit = i[5:0];
				bits = bits + 1;
			end
		if (bits > 1) ceil_bit = ceil_bit + 1'd1;
   end
endfunction

// Cart download control
wire        system_rom_write = ioctl_downl && (ioctl_index == 0 || ioctl_index == 3);
wire        cart_rom_no_adpcm = ioctl_index == 2;
wire        cart_rom_write = ioctl_downl && (ioctl_index == 1  || ioctl_index == 2);
reg         port1_req;
wire        port1_ack;
reg         port2_req;
wire        port2_ack;
`ifdef DUAL_SDRAM
reg         port22_req;
wire        port22_ack;
`endif
reg  [15:0] port2_q;
reg  [31:0] PSize, SSize, MSize, V1Size, V2Size, CSize;
reg  [31:0] P2Mask, CMask, V1Mask, V2Mask;
reg   [2:0] region;
reg  [26:0] offset;
reg  [26:0] region_size;
reg         pcm_merged;
wire [31:0] pcm_offset;
`ifdef DUAL_SDRAM
assign      pcm_offset = systype[1] ? CSize : 0;
`else
assign      pcm_offset = CSize;
`endif

always @(*) begin
	case (region)
		0: region_size = PSize[26:0];
		1: region_size = SSize[26:0];
		2: region_size = MSize[26:0];
		3: region_size = V1Size[26:0];
		4: region_size = V2Size[26:0];
		5: region_size = CSize[26:0];
		default: region_size = 0;
	endcase
end

wire SP_PCM_CS = CD_SPR_RD | CD_SPR_WR | CD_PCM_RD | CD_PCM_WR;
reg SP_PCM_CS_D;

always @(posedge CLK_96M) begin
	reg [1:0] written = 0;
	if (ioctl_wr) begin
		if (system_rom_write) begin
			written <= 0;
		end
		if (cart_rom_write) begin
			if (ioctl_addr[26:12] == 0) begin
				/*
				Header
				struct NeoFile
				{
					uint8_t header1, header2, header3, version;
					uint32_t PSize, SSize, MSize, V1Size, V2Size, CSize;
					uint32_t Year;
					uint32_t Genre;
					uint32_t Screenshot;
					uint32_t NGH;
					uint8_t Name[33];
					uint8_t Manu[17];
					uint8_t Filler[128 + 290];	//fill to 512
					uint8_t Filler2[4096 - 512];	//fill to 4096
				}
				*/
				region <= 0;
				offset <= 0;
				if (ioctl_addr >= 4 && ioctl_addr < 28)
					{CSize, V2Size, V1Size, MSize, SSize, PSize} <= {ioctl_dout, CSize, V2Size, V1Size, MSize, SSize, PSize[31:8]};

				if (&ioctl_addr[11:0]) begin
					written <= 2;
					pcm_merged <= 0;
					if (V2Size == 0) begin // Hack? Neobuilder merges ADPCMA+ADPCMB
						pcm_merged <= 1;
					end
				end
			end else begin
				// ROM data
				written <= 1;
			end
		end
	end
	case (written)
		1: // write acked, advance offset
		begin
			offset <= offset + 1'd1;
			written <= 2;
		end
		2: // check end of the region, advance until a region with >0 size found, or it's the last region
		if (offset == region_size) begin
			offset <= 0;
			region <= region + 1'd1;
			if (region == 5) written <= 0;
		end else begin
			written <= 0;
		end
		default: ;
	endcase

	if (cart_rom_write) begin
		CMask  <= (1<<ceil_bit(CSize)) - 1'd1;
		V1Mask <= (1<<ceil_bit(V1Size)) - 1'd1;
		V2Mask <= (1<<ceil_bit(V2Size)) - 1'd1;
		P2Mask <= 0;
		if (PSize > 32'h100000) P2Mask <= (1<<ceil_bit(PSize-32'h100000)) - 1'd1;
		ADPCM_EN <= !cart_rom_no_adpcm;
	end

	if (systype[1]) begin
		CMask <= 32'h3FFFFF;
		CSize <= 32'h400000;
		V1Mask <= 32'hFFFFF;
		ADPCM_EN <= 1;
	end
end

// download FIFO
// accept 8 bit data from the IO controller, shuffles fix and sprite tilemaps, and upload to SDRAM via 16 bit writes
reg  [26:0] dl_offset;
logic [1:0][7:0] dl_fifo[128]; // dual-width RAM (8 bit write side, 16 bit read side) for 2 pages of 128 bytes data
reg         dl_fifo_page  = 0; // write to this page, read from the other
reg   [6:0] dl_fifo_wr_addr;
wire  [6:1] dl_fifo_rd_addr = dl_offset[6:1];
reg         dl_fifo_read_start;
reg   [2:0] dl_region;
reg         dl_wr_state;
reg  [15:0] dl_fifo_out;
reg         dl_cart = 0, dl_sys = 0;

always @(*) begin
	if ((system_rom_write && ioctl_addr[23:17] == 7'b0000101) || (cart_rom_write && region == 1))
		dl_fifo_wr_addr = {ioctl_addr[6:5],ioctl_addr[2:0],~ioctl_addr[4],ioctl_addr[3]}; // FIX/SFIX
	else if (cart_rom_write && region == 5)
		dl_fifo_wr_addr = {ioctl_addr[5:2], ~ioctl_addr[6], ioctl_addr[0], ioctl_addr[1]}; // CROM
	else
	  dl_fifo_wr_addr = ioctl_addr[6:0];
end

always @(posedge CLK_96M) begin
	dl_fifo_read_start <= 0;
	if (!dl_cart & !dl_sys) dl_offset <= 0;
	dl_fifo_out <= dl_fifo[{~dl_fifo_page, dl_fifo_rd_addr}];

	// write from IO controller
	if (((cart_rom_write && ioctl_addr[26:12] != 0 && (!cart_rom_no_adpcm || region != 3 || region != 4)) || system_rom_write) && ioctl_wr) begin
		dl_fifo[{dl_fifo_page, dl_fifo_wr_addr[6:1]}][dl_fifo_wr_addr[0]] <= ioctl_dout;
		if (&ioctl_addr[6:0]) begin
			dl_fifo_read_start <= 1;
			dl_fifo_page <= ~dl_fifo_page;
			dl_region <= region;
			dl_wr_state <= 0;
			dl_cart <= cart_rom_write;
			dl_sys <= system_rom_write;
			if (cart_rom_write && dl_region != region) dl_offset <= 0;
		end
	end

	// send to SDRAM
	if (!dl_wr_state) begin
		if ((dl_fifo_read_start || |dl_fifo_rd_addr) && !dl_wr_state) begin
			// System ROM/PROM/FIX/MROM
			if (dl_sys || (dl_cart && dl_region < 3)) begin
				port1_req <= ~port1_req;
				dl_wr_state <= 1;
			end
			// ADPCM ROMs
			if (dl_cart && (dl_region == 3 || dl_region == 4)) begin
				port2_req <= ~port2_req;
				dl_wr_state <= 1;
			end
			// CROM
			if (dl_cart && dl_region == 5) begin
`ifdef DUAL_SDRAM
				port22_req <= ~port22_req;
`else
				port2_req <= ~port2_req;
`endif
				dl_wr_state <= 1;
			end
		end

		if (!dl_fifo_read_start && dl_fifo_rd_addr == 0 && !ioctl_downl) begin
			dl_cart <= 0;
			dl_sys <= 0;
		end

	end
	else // dl_wr_state
	begin

		if (
			((dl_sys || (dl_cart && dl_region < 3)) && port1_req == port1_ack) ||
			(dl_cart && (dl_region == 3 || dl_region == 4) && port2_req == port2_ack) ||
`ifdef DUAL_SDRAM
			(dl_cart && dl_region == 5 && port22_req == port22_ack)
`else
			(dl_cart && dl_region == 5 && port2_req == port2_ack)
`endif
		) begin
			dl_wr_state <= 0;
			dl_offset <= dl_offset + 2'd2;
		end
	end

	// CD System sprite/PCM area read/write
	SP_PCM_CS_D <= SP_PCM_CS;

	if (!SP_PCM_CS_D & SP_PCM_CS) begin
		port2_req <= ~port2_req;
	end else if (port2_req == port2_ack)
		SP_PCM_READY <= 1;

	if (!SP_PCM_CS) SP_PCM_READY <= 0;

end

wire [23:0] system_port1_addr = dl_offset[23:19] == 0 ? { 5'b1111_1, dl_offset[18:0] } : // system ROM
                                dl_offset[23:17] == 7'b0000100 ? { 8'b1101_1110, dl_offset[15:0] } : // LO ROM
                                dl_offset[23:17] == 7'b0000101 ? { 7'b1110_100, dl_offset[16:0] } : // SFIX ROM
                                        { 6'b1110_11, dl_offset[17:0] }; // SM1

wire [23:0] cart_port1_addr = dl_region == 1 ? { 5'b1110_0, dl_offset[18:0] } : // FIX ROM
							                dl_region == 2 ? { 5'b1111_0, dl_offset[18:0] } : // MROM
							                dl_offset[23:0]; // PROM

wire [23:0] port1_addr = system_rom_write ? system_port1_addr : cart_port1_addr;

wire [25:0] port2_addr = (CD_SPR_RD | CD_SPR_WR) ? P2ROM_ADDR[21:0] : 
                         (CD_PCM_RD | CD_PCM_WR) ? {4'h4, P2ROM_ADDR[19:0]} :
                         dl_region == 3 ? pcm_offset + dl_offset : // V1 ROM
                         dl_region == 4 ? pcm_offset + V1Size + dl_offset : // V2 ROM
					               dl_offset[25:0]; // CROM

// VRAM->SDRAM control
always @(posedge CLK_48M) begin
	reg SLOW_VRAM_WE_OLD;
	reg SLOW_VRAM_RD_OLD;
	reg [14:0] SPRMAP_ADDR_OLD;
	reg [14:0] SLOW_VRAM_ADDR_OLD;

	SLOW_VRAM_WE_OLD <= SLOW_VRAM_WE;
	SLOW_VRAM_RD_OLD <= SLOW_VRAM_RD;

	if ((!SLOW_VRAM_WE_OLD && SLOW_VRAM_WE) || (!SLOW_VRAM_RD_OLD && SLOW_VRAM_RD && SLOW_VRAM_ADDR_OLD != SLOW_VRAM_ADDR)) begin
		sdr_vram_req <= ~sdr_vram_req;
		sdr_vram_addr <= SLOW_VRAM_ADDR;
		sdr_vram_we <= SLOW_VRAM_WE;
		sdr_vram_d <= SLOW_VRAM_DATA_OUT;
		sdr_vram_sel <= 1;
		SLOW_VRAM_ADDR_OLD <= SLOW_VRAM_ADDR;
	end
	else
	if (sdr_vram_req == sdr_vram_ack && SPRMAP_RD && SPRMAP_ADDR[14:1] != SPRMAP_ADDR_OLD[14:1]) begin
		sdr_vram_req <= ~sdr_vram_req;
		sdr_vram_addr <= SPRMAP_ADDR;
		sdr_vram_we <= 0;
		sdr_vram_sel <= 0;
		SPRMAP_ADDR_OLD <= SPRMAP_ADDR;
	end
end

// LO ROM->SDRAM control
always @(posedge CLK_48M) begin
	reg [15:0] LO_ROM_ADDR_OLD;
	if (LO_ROM_RD) begin
		LO_ROM_ADDR_OLD <= LO_ROM_ADDR;
		if (LO_ROM_ADDR_OLD[15:1] != LO_ROM_ADDR[15:1]) lo_rom_req <= ~lo_rom_req;
	end
end

// CROM->SDRAM control
always @(posedge CLK_48M) begin
	reg CROM_RD_OLD;
	CROM_RD_OLD <= CROM_RD;
	if (CROM_RD_OLD & !CROM_RD) sp_req <= ~sp_req;
end

// ADPCM->SDRAM control
reg        ADPCM_EN;
reg [23:0] ADPCMA_ADDR_LATCH;
reg [23:0] ADPCMB_ADDR_LATCH;
always @(posedge CLK_48M) begin
	reg ADPCMA_RD_OLD, ADPCMB_RD_OLD;
	ADPCMA_RD_OLD <= ADPCMA_RD;
	ADPCMB_RD_OLD <= ADPCMB_RD;
	if (!ADPCMA_RD_OLD & ADPCMA_RD & ADPCM_EN) begin
		if (ADPCMA_ADDR_LATCH[23:2] != {ADPCMA_BANK, ADPCMA_ADDR[19:2]}) sample_roma_req <= ~sample_roma_req;
		ADPCMA_ADDR_LATCH <= {ADPCMA_BANK, ADPCMA_ADDR} & V1Mask;
	end
	if (!ADPCMB_RD_OLD & ADPCMB_RD & ADPCM_EN) begin
		if (ADPCMB_ADDR_LATCH[23:2] != ADPCMB_ADDR[23:2]) sample_romb_req <= ~sample_romb_req;
		ADPCMB_ADDR_LATCH <= ADPCMB_ADDR & (pcm_merged ? V1Mask : V2Mask);
	end
end

assign sample_roma_addr = pcm_offset + ADPCMA_ADDR_LATCH;
assign sample_romb_addr = pcm_offset + ({32{~pcm_merged}} & V1Size) + ADPCMB_ADDR_LATCH;
assign ADPCMA_DATA_READY = sample_roma_req == sample_roma_ack;
assign ADPCMB_DATA_READY = sample_romb_req == sample_romb_ack;

always @(*) begin
	if (!ADPCM_EN)
		ADPCMA_DATA = 8'h80;
	else
	case (ADPCMA_ADDR_LATCH[1:0])
	3'd0: ADPCMA_DATA = sample_roma_dout[ 7: 0];
	3'd1: ADPCMA_DATA = sample_roma_dout[15: 8];
	3'd2: ADPCMA_DATA = sample_roma_dout[23:16];
	3'd3: ADPCMA_DATA = sample_roma_dout[31:24];
	default: ;
	endcase
end

always @(*) begin
	if (!ADPCM_EN)
		ADPCMB_DATA = 8'h80;
	else
	case (ADPCMB_ADDR_LATCH[1:0])
	3'd0: ADPCMB_DATA = sample_romb_dout[ 7: 0];
	3'd1: ADPCMB_DATA = sample_romb_dout[15: 8];
	3'd2: ADPCMB_DATA = sample_romb_dout[23:16];
	3'd3: ADPCMB_DATA = sample_romb_dout[31:24];
	default: ;
	endcase
end

// Bank 0-1-2 address map
// CROM    (CSize)
// V1ROM   (V1Size)
// V2ROM   (V2Size)

// Bank 3 address map
// xxxx xxxx xxxx xxxx xxxx xxxx    P1/2 ROMs
// 1101 1100 xxxx xxxx xxxx xxxx    VRAM
// 1101 111x xxxx xxxx xxxx xxxx    LO ROM
// 1110 0xxx xxxx xxxx xxxx xxxx    FIX ROM
// 1110 100x xxxx xxxx xxxx xxxx    SFIX
// 1110 1010 xxxx xxxx xxxx xxxx    SRAM
// 1110 1011 xxxx xxxx xxxx xxxx    WRAM
// 1110 11xx xxxx xxxx xxxx xxxx    SM1 
// 1111 0xxx xxxx xxxx xxxx xxxx    Z80 Cart ROM
// 1111 1xxx xxxx xxxx xxxx xxxx    SROM
reg [23:0] ROM_ADDR;
always @(*) begin
	if (SROM_RD)                             ROM_ADDR = { 5'b11111, P2ROM_ADDR[18:0] };
	else if (ROM_RD)                         ROM_ADDR = P2ROM_ADDR[19:0];
	else if (CD_EXT_RD | CD_EXT_WR)          ROM_ADDR = P2ROM_ADDR[20:0];
	else if (CD_FIX_RD | CD_FIX_WR)          ROM_ADDR = { 6'b111000, P2ROM_ADDR[17:0] };
	else if (WRAM_WE | WRAM_RD)              ROM_ADDR = { 8'b11101011, P2ROM_ADDR[15:0] };
	else if (SRAM_WE | SRAM_RD)              ROM_ADDR = { 8'b11101010, P2ROM_ADDR[15:0] };
	else                                     ROM_ADDR = 24'h100000 + (P2ROM_ADDR[23:0] & P2Mask[23:0]);
end

wire  [1:0] ROM_WR_DS = {2{(CD_EXT_WR | CD_FIX_WR | SRAM_WE | WRAM_WE)}} & PROM_DS;
wire [15:0] P2ROM_Q;
wire        P2ROM_DATA_READY;
assign PROM_DATA = (CD_SPR_RD | CD_PCM_RD) ? port2_q : P2ROM_Q;
assign PROM_DATA_READY = SP_PCM_READY | P2ROM_DATA_READY;

sdram_2w_cl2 #(96) sdram
(
  .*,
  .init_n        ( pll_locked   ),
  .clk           ( CLK_96M      ),
  .clkref        ( SFIX_RD      ),
  .refresh_en    ( HBlank | VBlank | ioctl_downl ),

  // Bank 3 ops
  .port1_a       ( port1_addr[23:1] ),
  .port1_req     ( port1_req  ),
  .port1_ack     ( port1_ack ),
  .port1_we      ( system_rom_write | cart_rom_write ),
  .port1_ds      ( 2'b11 ),
  .port1_d       ( dl_fifo_out ),
  .port1_q       (  ),

  // Main CPU
  .cpu1_rom_addr ( ROM_ADDR[23:1] ),
  .cpu1_rom_cs   ( CD_EXT_RD | CD_EXT_WR | CD_FIX_RD | CD_FIX_WR | ROM_RD | PORT_RD | SROM_RD | WRAM_RD | SRAM_RD | WRAM_WE | SRAM_WE ),
  .cpu1_rom_ds   ( ROM_WR_DS ), // for write, 00 for read
  .cpu1_rom_d    ( PROM_DOUT ),
  .cpu1_rom_q    ( P2ROM_Q ),
  .cpu1_rom_valid( P2ROM_DATA_READY ),

  // Audio CPU
  .cpu2_rom_addr ( SYSTEM_ROMS ? { 6'b111011, Z80_ROM_ADDR[17:1] } : { 5'b11110, Z80_ROM_ADDR[18:1] } ),
  .cpu2_rom_rd   ( Z80_ROM_RD ),
  .cpu2_rom_wr   ( Z80_ROM_WR ),
  .cpu2_rom_ds   ( {Z80_ROM_ADDR[0], !Z80_ROM_ADDR[0]} ),
  .cpu2_rom_d    ( Z80_ROM_DOUT  ),
  .cpu2_rom_q    ( Z80_ROM_DATA  ),
  .cpu2_rom_valid( Z80_ROM_READY ),

  // FIX ROM
  .sfix_cs       ( ~SFIX_RD & ~ioctl_downl ),
  .sfix_addr     ( SYSTEM_ROMS ? { 7'b1110100, SFIX_ADDR[15:0] } : { 5'b11100, SFIX_ADDR[17:0] } ),
  .sfix_q        ( SFIX_DATA ),

  // LO ROM
  .lo_rom_req    ( lo_rom_req & ~ioctl_downl ),
  .lo_rom_ack    ( ),
  .lo_rom_addr   ( { 8'b1101_1110, LO_ROM_ADDR[15:1] } ),
  .lo_rom_q      ( LO_ROM_DATA ),

  // VRAM
  .vram_addr     ( { 8'b1101_1100, sdr_vram_addr[14:0] } ),
  .vram_req      ( sdr_vram_req ),
  .vram_q1       ( SLOW_VRAM_DATA_IN_SPR ),
  .vram_q2       ( SLOW_VRAM_DATA_IN_CPU ),
  .vram_d        ( sdr_vram_d  ),
  .vram_we       ( sdr_vram_we ),
  .vram_ack      ( sdr_vram_ack ),
  .vram_sel      ( sdr_vram_sel ),

  // Bank 0-1-2 ops
  .port2_a       ( port2_addr[25:1] ),
  .port2_req     ( port2_req ),
  .port2_ack     ( port2_ack ),
  .port2_we      ( CD_SPR_WR | CD_PCM_WR | dl_cart ),
  .port2_ds      ( dl_cart ? 2'b11 : PROM_DS ),
  .port2_d       ( dl_cart ? dl_fifo_out : PROM_DOUT ),
  .port2_q       ( port2_q ),

  .samplea_addr  ( sample_roma_addr ),
  .samplea_q     ( sample_roma_dout ),
  .samplea_req   ( sample_roma_req  ),
  .samplea_ack   ( sample_roma_ack  ),

  .sampleb_addr  ( sample_romb_addr ),
  .sampleb_q     ( sample_romb_dout ),
  .sampleb_req   ( sample_romb_req  ),
  .sampleb_ack   ( sample_romb_ack  ),
`ifdef DUAL_SDRAM
  .sp_req        ( sp_req & systype[1] ),
`else
  .sp_req        ( sp_req ),
`endif
  .sp_ack        (  ),
  .sp_addr       ( CROM_ADDR[25:2] & CMask[25:2] ),
  .sp_q          ( CROM_DATA1 )
);

`ifdef DUAL_SDRAM
wire CLK2_96M;
wire pll2_locked;
pll_mist pll2(
	.inclk0(CLOCK_27),
	.c0(CLK2_96M),
	.locked(pll2_locked)
	);

assign SDRAM2_CKE = 1;
assign SDRAM2_CLK = CLK2_96M;

sdram_2w_cl2 #(96, 0) sdram2
(
  .SDRAM_A       ( SDRAM2_A ),
  .SDRAM_DQ      ( SDRAM2_DQ ),
  .SDRAM_DQML    ( SDRAM2_DQML ),
  .SDRAM_DQMH    ( SDRAM2_DQMH ),
  .SDRAM_nWE     ( SDRAM2_nWE  ),
  .SDRAM_nCAS    ( SDRAM2_nCAS ),
  .SDRAM_nRAS    ( SDRAM2_nRAS ),
  .SDRAM_nCS     ( SDRAM2_nCS ),
  .SDRAM_BA      ( SDRAM2_BA ),

  .init_n        ( pll2_locked   ),
  .clk           ( CLK2_96M     ),
  .clkref        ( SFIX_RD      ),
  .refresh_en    ( 1'b1         ),

  .port2_a       ( port2_addr[25:1] ),
  .port2_req     ( port22_req ),
  .port2_ack     ( port22_ack ),
  .port2_we      ( dl_cart ),
  .port2_ds      ( 2'b11 ),
  .port2_d       ( dl_fifo_out ),
  .port2_q       (  ),

  .sp_req        ( sp_req & !systype[1] ),
  .sp_ack        (  ),
  .sp_addr       ( CROM_ADDR[25:2] & CMask[25:2] ),
  .sp_q          ( CROM_DATA2 )
);
`endif

wire       ms_xy;
reg  [7:0] ms_x, ms_y;
wire [7:0] ms_pos = ms_xy ? ms_y : ms_x;
wire [7:0] ms_btn = {2'b00, mouse_flags[1:0], 4'b0000};

always @(posedge CLK_48M) begin
	if(mouse_strobe) begin
		ms_x <= ms_x + mouse_x;
		ms_y <= ms_y - mouse_y;
	end
end

wire [15:0] ch_left, ch_right;
wire  [7:0] R, G, B;
wire        HBlank, VBlank, HSync, VSync;
wire        ce_pix;
wire  [9:0] P1_IN = {m_fireC , m_fireD | mouse_flags[2], mouse_en ? ms_pos : {m_fireF,  m_fireE,  m_fireB,  m_fireA,  m_right,  m_left,  m_down,  m_up }};
wire  [9:0] P2_IN = {m_fire2C, m_fire2D                , mouse_en ? ms_btn : {m_fire2F, m_fire2E, m_fire2B, m_fire2A, m_right2, m_left2, m_down2, m_up2}};

neogeo_top neogeo_top (
	.CLK_48M       ( CLK_48M ),
	.RESET         ( reset   ),

	.VIDEO_MODE    ( vmode ),
	.SYSTEM_TYPE   ( systype ),
	.MEMCARD_EN    ( bk_ena ),
	.COIN1         ( m_coin1 ),
	.COIN2         ( m_coin2 ),
	.P1_IN         ( P1_IN ),
	.P2_IN         ( P2_IN ),
	.DIPSW         ( dipsw ),
	.MS_XY         ( ms_xy ),
	.DBG_FIX_EN    ( fix_en ),
	.DBG_SPR_EN    ( spr_en ),
	.RTC           ( rtc ),

	.CD_REGION_SEL    ( cd_region ),
	.CD_LID           ( cd_lid ),
	.CD_SPEED         ( cd_speed ),
	.CDD_STATUS_IN    ( CDD_STATUS_IN ),
	.CDD_STATUS_LATCH ( CDD_STATUS_LATCH ),
	.CDD_COMMAND_DATA ( CDD_COMMAND_DATA ),
	.CDD_COMMAND_SEND ( CDD_COMMAND_SEND ),
	.CD_DATA_DOWNLOAD ( CD_DATA_DOWNLOAD ),
	.CD_DATA_WR       ( CD_DATA_WR ),
	.CD_DATA_DIN      ( CD_DATA_DIN ),
	.CD_DATA_ADDR     ( CD_DATA_ADDR ),
	.CD_DATA_WR_READY ( CD_DATA_WR_READY ),
	.CDDA_WR          ( CDDA_WR ),
	.CDDA_WR_READY    ( CDDA_WR_READY ),
	.CD_AUDIO_L       ( CD_AUDIO_L ),
	.CD_AUDIO_R       ( CD_AUDIO_R ),

	.RED           ( R ),
	.GREEN         ( G ),
	.BLUE          ( B ),
	.HSYNC         ( HSync ),
	.VSYNC         ( VSync ),
	.HBLANK        ( HBlank ),
	.VBLANK        ( VBlank ),

	.LSOUND        ( ch_left ),
	.RSOUND        ( ch_right ),

	.CE_PIXEL      ( ce_pix ),

`ifdef CARTOPTS
	.CART_PCHIP    ( pchip ),
	.CART_CHIP     ( {linkmcu, proct0} ), // legacy option: 0 - none, 1 - PRO-CT0, 2 - Link MCU
	.CMC_CHIP      ( cmcchip ),           // type 1/2
	.ROM_WAIT      ( romwait ),           // ROMWAIT from cart. 0 - Full speed, 1 - 1 wait cycle
	.P_WAIT        ( pwait ),             // PWAIT from cart. 0 - Full speed, 1 - 1 wait cycle, 2 - 2 cycles	
`endif

	.CLK_MEMCARD   ( CLK_48M      ),
	.MEMCARD_ADDR  ( MEMCARD_ADDR ),
	.MEMCARD_WR    ( MEMCARD_WR   ),
	.MEMCARD_DIN   ( MEMCARD_DIN  ),
	.MEMCARD_DOUT  ( MEMCARD_DOUT ),

	.P2ROM_ADDR          ( P2ROM_ADDR ),
	.PROM_DATA           ( PROM_DATA  ),
	.PROM_DOUT           ( PROM_DOUT  ),
	.PROM_DS             ( PROM_DS ),
	.PROM_DATA_READY     ( PROM_DATA_READY ),
	.ROM_RD              ( ROM_RD ),
	.PORT_RD             ( PORT_RD ),
	.SROM_RD             ( SROM_RD ),
	.WRAM_WE             ( WRAM_WE ),
	.WRAM_RD             ( WRAM_RD ),
	.SRAM_WE             ( SRAM_WE ),
	.SRAM_RD             ( SRAM_RD ),
	.CD_EXT_RD           ( CD_EXT_RD ),
	.CD_EXT_WR           ( CD_EXT_WR ),
	.CD_FIX_RD           ( CD_FIX_RD ),
	.CD_FIX_WR           ( CD_FIX_WR ),
	.CD_SPR_RD           ( CD_SPR_RD ),
	.CD_SPR_WR           ( CD_SPR_WR ),
	.CD_PCM_RD           ( CD_PCM_RD ),
	.CD_PCM_WR           ( CD_PCM_WR ),

	.SYSTEM_ROMS         ( SYSTEM_ROMS ),
	.SFIX_ADDR           ( SFIX_ADDR ),
	.SFIX_DATA           ( SFIX_DATA ),
	.SFIX_RD             ( SFIX_RD   ),

	.LO_ROM_ADDR         ( LO_ROM_ADDR ),
	.LO_ROM_RD           ( LO_ROM_RD ),
	.LO_ROM_DATA         ( LO_ROM_ADDR[0] ? LO_ROM_DATA[15:8] : LO_ROM_DATA[7:0] ),

	.CROM_ADDR           ( CROM_ADDR ),
	.CROM_DATA           ( CROM_DATA ),
	.CROM_RD             ( CROM_RD   ),

	.Z80_ROM_ADDR        ( Z80_ROM_ADDR ),
	.Z80_ROM_RD          ( Z80_ROM_RD   ),
	.Z80_ROM_WR          ( Z80_ROM_WR   ),
	.Z80_ROM_DATA        ( Z80_ROM_ADDR[0] ? Z80_ROM_DATA[15:8] : Z80_ROM_DATA[7:0] ),
	.Z80_ROM_DOUT        ( Z80_ROM_DOUT ),
	.Z80_ROM_READY       ( Z80_ROM_READY ),

	.SLOW_SCB1_VRAM_ADDR      ( SLOW_VRAM_ADDR ),
	.SLOW_SCB1_VRAM_DATA_IN   ( SLOW_VRAM_DATA_IN ),
	.SLOW_SCB1_VRAM_DATA_OUT  ( SLOW_VRAM_DATA_OUT ),
	.SLOW_SCB1_VRAM_RD        ( SLOW_VRAM_RD ),
	.SLOW_SCB1_VRAM_WE        ( SLOW_VRAM_WE ),

	.SPRMAP_ADDR         ( SPRMAP_ADDR ),
	.SPRMAP_RD           ( SPRMAP_RD ),
	.SPRMAP_DATA         ( SPRMAP_DATA ),

	.ADPCMA_ADDR         ( ADPCMA_ADDR ),
	.ADPCMA_BANK         ( ADPCMA_BANK ),
	.ADPCMA_RD           ( ADPCMA_RD   ),
	.ADPCMA_DATA         ( ADPCMA_DATA ),
	.ADPCMA_DATA_READY   ( ADPCMA_DATA_READY ),
	.ADPCMB_ADDR         ( ADPCMB_ADDR ),
	.ADPCMB_RD           ( ADPCMB_RD   ),
	.ADPCMB_DATA         ( ADPCMB_DATA ),
	.ADPCMB_DATA_READY   ( ADPCMB_DATA_READY )
);

mist_video #(.COLOR_DEPTH(8), .SD_HCNT_WIDTH(9), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(VGA_BITS)) mist_video(
	.clk_sys        ( CLK_48M          ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R              ( R                ),
	.G              ( G                ),
	.B              ( B                ),
	.HBlank         ( HBlank           ),
	.VBlank         ( VBlank           ),
	.HSync          ( HSync            ),
	.VSync          ( VSync            ),
	.VGA_R          ( VGA_R            ),
	.VGA_G          ( VGA_G            ),
	.VGA_B          ( VGA_B            ),
	.VGA_VS         ( VGA_VS           ),
	.VGA_HS         ( VGA_HS           ),
	.rotate         ( { orientation[1], rotate } ),
	.ce_divider     ( 3'd7             ),
	.scandoubler_disable( scandoublerD ),
	.scanlines      ( scanlines        ),
	.blend          ( blend            ),
	.ypbpr          ( ypbpr            ),
	.no_csync       ( no_csync         )
	);

wire signed [16:0] au_left  = $signed(ch_left ) + $signed(CD_AUDIO_L);
wire signed [16:0] au_right = $signed(ch_right) + $signed(CD_AUDIO_R);

dac #(
	.C_bits(17))
dacl(
	.clk_i(CLK_48M),
	.res_n_i(1),
	.dac_i({~au_left[16], au_left[15:0]}),
	.dac_o(AUDIO_L)
	);

dac #(
	.C_bits(17))
dacr(
	.clk_i(CLK_48M),
	.res_n_i(1),
	.dac_i({~au_right[16], au_right[15:0]}),
	.dac_o(AUDIO_R)
	);

`ifdef I2S_AUDIO
wire i2s_ce;
CEGen CEGEN_BCLK
(
	.CLK(CLK_48M),
	.RST_N(~reset),
	.IN_CLK(48000000),
	.OUT_CLK(1536000),
	.CE(i2s_ce)
);

i2s i2s (
	.reset(reset),
	.clk(CLK_48M),
	.ce(i2s_ce),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(au_left[16:1]),
	.right_chan(au_right[16:1])
);
`endif
	
wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
wire m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;

arcade_inputs #(.COIN1(10), .COIN2(11)) inputs (
	.clk         ( CLK_48M     ),
	.key_strobe  ( key_strobe  ),
	.key_pressed ( key_pressed ),
	.key_code    ( key_code    ),
	.joystick_0  ( joystick_0  ),
	.joystick_1  ( joystick_1  ),
	.rotate      ( rotate      ),
	.orientation ( orientation ),
	.joyswap     ( joyswap     ),
	.oneplayer   ( oneplayer   ),
	.controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
	.player1     ( {m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right} ),
	.player2     ( {m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2} )
);

// Backup RAM handler
reg    [7:0] sd_buff_dout_odd;
wire  [11:0] MEMCARD_ADDR = {sd_lba[3:0], sd_buff_addr[8:1]};
wire         MEMCARD_WR = bk_load & sd_buff_wr & sd_buff_addr[0];
wire  [15:0] MEMCARD_DIN = {sd_buff_dout, sd_buff_dout_odd};
wire  [15:0] MEMCARD_DOUT;
assign       sd_buff_din = sd_buff_addr[0] ? MEMCARD_DOUT[15:8] : MEMCARD_DOUT[7:0];

always @(posedge CLK_48M) if (sd_buff_wr & !sd_buff_addr[0]) sd_buff_dout_odd <= sd_buff_dout;

reg  bk_ena     = 0;
reg  bk_load    = 0;
//reg  bk_reset   = 0;
reg [31:9] bk_size;

always @(posedge CLK_48M) begin
	reg  old_load = 0, old_save = 0, old_ack, old_mounted = 0;
	reg  bk_state = 0;

	//bk_reset <= 0;

	old_mounted <= img_mounted[0];
	if(~old_mounted && img_mounted[0]) begin
		if (|img_size) begin
			bk_ena <= 1;
			bk_load <= 1;
			bk_size <= img_size[31:9];
		end else
			bk_ena <= 0;
	end

	old_load <= bk_load;
	old_save <= bk_save;
	old_ack  <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if(!bk_state) begin
		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save))) begin
			bk_state <= 1;
			sd_lba <= 0;
			sd_rd <=  bk_load;
			sd_wr <= ~bk_load;
		end
	end else begin
		if(old_ack & ~sd_ack) begin
			if(&sd_lba[3:0] || sd_lba == bk_size) begin
				//if (bk_load) bk_reset <= 1;
				bk_load <= 0;
				bk_state <= 0;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_load;
				sd_wr  <= ~bk_load;
			end
		end
	end
end
endmodule 
