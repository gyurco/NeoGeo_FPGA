//
// sdram.v
//
// sdram controller implementation for the MiST board
// https://github.com/mist-devel/mist-board
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2019-2022 Gyorgy Szombathelyi
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module sdram_2w_cl2 (

	// interface to the MT48LC16M16 chip
	inout      [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [12:0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg        SDRAM_DQML, // two byte masks
	output reg        SDRAM_DQMH, // two byte masks
	output reg [1:0]  SDRAM_BA,   // two banks
	output            SDRAM_nCS,  // a single chip select
	output            SDRAM_nWE,  // write enable
	output            SDRAM_nRAS, // row address select
	output            SDRAM_nCAS, // columns address select

	// cpu/chipset interface
	input             init_n,     // init signal after FPGA config to initialize RAM
	input             clk,        // sdram clock
	input             clkref,     // external signal to sync the state machine
	input             refresh_en,

	// 1st bank
	input             port1_req,
	output reg        port1_ack = 0,
	input             port1_we,
	input      [23:1] port1_a,
	input       [1:0] port1_ds,
	input      [15:0] port1_d,
	output reg [15:0] port1_q,

	// cpu1 rom/ram
	input      [23:1] cpu1_rom_addr,
	input             cpu1_rom_cs,
	input       [1:0] cpu1_rom_ds, // for write
	input      [15:0] cpu1_rom_d,
	output reg [15:0] cpu1_rom_q,
	output reg        cpu1_rom_valid,

	// cpu2 rom
	input      [23:1] cpu2_rom_addr,
	input             cpu2_rom_rd,
	input             cpu2_rom_wr,
	input       [1:0] cpu2_rom_ds,
	input       [7:0] cpu2_rom_d,
	output reg [15:0] cpu2_rom_q,
	output reg        cpu2_rom_valid,

	// fix rom
	input             sfix_cs,
	input      [23:1] sfix_addr,
	output reg [15:0] sfix_q,

	// lo rom
	input             lo_rom_req,
	output reg        lo_rom_ack = 0,
	input      [23:1] lo_rom_addr,
	output reg [15:0] lo_rom_q,

	// vram
	input             vram_req,
	output reg        vram_ack = 0,
	input      [23:1] vram_addr,
	input             vram_we,
	input      [15:0] vram_d,
	output reg [31:0] vram_q1,
	output reg [15:0] vram_q2,
	input             vram_sel,

	// 2nd bank
	input             port2_req,
	output reg        port2_ack = 0,
	input             port2_we,
	input      [25:1] port2_a,
	input       [1:0] port2_ds,
	input      [15:0] port2_d,
	output reg [31:0] port2_q,

	input             samplea_req,
	output reg        samplea_ack = 0,
	input      [25:0] samplea_addr,
	output reg [31:0] samplea_q,

	input             sampleb_req,
	output reg        sampleb_ack = 0,
	input      [25:0] sampleb_addr,
	output reg [31:0] sampleb_q,

	input             sp_req,
	output reg        sp_ack = 0,
	input      [25:2] sp_addr,
	output reg [31:0] sp_q
);

parameter  MHZ = 16'd80; // 80 MHz default clock, set it to proper value to calculate refresh rate
parameter  DUAL_BANK      = 1'b1;   // split the address space into two parts (bank 0-1-2 / 3)

localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 2 cycles@<100MHz
localparam BURST_LENGTH   = 3'b001; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// 64ms/8192 rows = 7.8us
localparam RFRSH_CYCLES = 16'd78*MHZ/4'd10;

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

/*
 SDRAM state machine for 2 bank interleaved access
 2 word burst, CL2
cmd issued  registered
 0 RAS0     data1 returned
 1          ras0 - data1 returned
 2 CAS0
 3 RAS1
 4          ras1
 5 CAS1(r)  data0 returned
 6 CAS1(w)  cas1(r) - data0 returned
 7          cas1(w)
*/

localparam STATE_RAS0      = 3'd0;   // first state in cycle
localparam STATE_RAS1      = 3'd3;   // Second ACTIVE command after RAS0 + tRRD (15ns)
localparam STATE_CAS0      = STATE_RAS0 + RASCAS_DELAY; // CAS phase - 2
localparam STATE_CAS1      = STATE_RAS1 + RASCAS_DELAY; // CAS phase - 5
localparam STATE_READ0     = STATE_CAS0 + CAS_LATENCY + 2'd2; // 6
localparam STATE_READ0b    = STATE_READ0 + 1'd1;
localparam STATE_DS0b      = STATE_CAS0 + 1'd1;
localparam STATE_READ1     = 3'd1;
localparam STATE_DS1b      = STATE_CAS1 + 1'd1;
localparam STATE_READ1b    = 3'd2;
localparam STATE_LAST      = 3'd7;

reg [3:0] t;

always @(posedge clk) begin
	reg clkref_d;
	t <= t + 1'd1;
	if (t == STATE_LAST) t <= STATE_RAS0;
	//if (t == STATE_RAS0 && !refresh && !oe_next[0] && !we_next[0] && !oe_next[1] && !we_next[1] && !oe_latch[1] && !we_latch[1]) t <= STATE_RAS0;
	//if (t == STATE_RAS0 && !refresh && !oe_next[0] && !we_next[0] && (oe_next[1] || we_next[1]) && !oe_latch[1] && !we_latch[1]) t <= STATE_RAS1;
	//if (t == STATE_RAS1 && !oe_latch[0] && !we_latch[0] && !oe_next[1] && !we_next[1] && !need_refresh) t <= STATE_RAS0;
	clkref_d <= clkref;
	if (clkref_d & ~clkref & t != STATE_RAS0 & ~|oe_latch) t <= t;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [4:0]  reset;
reg        init = 1'b1;
always @(posedge clk, negedge init_n) begin
	if(!init_n) begin
		reset <= 5'h1f;
		init <= 1'b1;
	end else begin
		if((t == STATE_LAST) && (reset != 0)) reset <= reset - 5'd1;
		init <= !(reset == 0);
	end
end

// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

reg [3:0]  sd_cmd;   // current command sent to sd ram
reg [15:0] sd_din;
reg [15:0] sd_dout;
reg        oe;
// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];
assign SDRAM_DQ = oe ? sd_dout : 16'hZZZZ;

reg [25:1] addr_latch[2];
reg [25:1] addr_next[2];
reg [15:0] din_next[2];
reg [15:0] din_latch[2];
reg  [1:0] oe_next;
reg  [1:0] oe_latch;
reg  [1:0] we_next;
reg  [1:0] we_latch;
reg  [1:0] ds_next[2];
reg  [1:0] ds[2];

reg        port1_state;
reg        port2_state;
reg        vram_req_state, vram_sel_latch;
reg        sfix_valid;
reg        lo_rom_req_state;
reg        sp_req_state;
reg        samplea_req_state;
reg        sampleb_req_state;
wire       cpu2_rom_cs = cpu2_rom_rd | cpu2_rom_wr;

localparam PORT_NONE     = 3'd0;
localparam PORT_CPU1_ROM = 3'd1;
localparam PORT_CPU2_ROM = 3'd3;
localparam PORT_SFIX     = 3'd4;
localparam PORT_VRAM     = 3'd5;
localparam PORT_LOROM    = 3'd6;
localparam PORT_SAMPLEA  = 3'd1;
localparam PORT_SAMPLEB  = 3'd2;
localparam PORT_SP       = 3'd3;
localparam PORT_REQ      = 3'd7;

reg  [2:0] next_port[2];
reg  [2:0] port[2];

reg  [2:0] refresh;
reg [23:0] refresh_cnt;
wire       need_refresh = (refresh_cnt >= RFRSH_CYCLES);

// PORT1: bank 3
always @(*) begin
	next_port[0] = PORT_NONE;
	addr_next[0] = addr_latch[0];
	ds_next[0] = 2'b00;
	{ oe_next[0], we_next[0] } = 2'b00;
	din_next[0] = 0;
	addr_next[0][25:24] = 3; //BA

	if (&refresh) begin
		// nothing
	end else if (port1_req ^ port1_state) begin
		next_port[0] = PORT_REQ;
		addr_next[0][23:1] = port1_a;
		ds_next[0] = port1_ds;
		{ oe_next[0], we_next[0] } = { ~port1_we, port1_we };
		din_next[0] = port1_d;
	end else if (vram_req ^ vram_req_state) begin
		next_port[0] = PORT_VRAM;
		addr_next[0][23:1] = {vram_addr[23:2], vram_addr[1] & vram_sel};
		ds_next[0] = 2'b11;
		din_next[0] = vram_d;
		{ oe_next[0], we_next[0] } = { ~vram_we, vram_we };
	end else if (lo_rom_req ^ lo_rom_req_state) begin
		next_port[0] = PORT_LOROM;
		addr_next[0][23:1] = lo_rom_addr[23:1];
		ds_next[0] = 2'b11;
		{ oe_next[0], we_next[0] } = 2'b10;
	end else if (sfix_cs & !sfix_valid) begin
		next_port[0] = PORT_SFIX;
		addr_next[0][23:1] = sfix_addr[23:1];
		ds_next[0] = 2'b11;
		{ oe_next[0], we_next[0] } = 2'b10;
	end else if (cpu1_rom_cs && !cpu1_rom_valid) begin
		next_port[0] = PORT_CPU1_ROM;
		addr_next[0][23:1] = cpu1_rom_addr[23:1];
		ds_next[0] = |cpu1_rom_ds ? cpu1_rom_ds : 2'b11;
		{ oe_next[0], we_next[0] } = {~|cpu1_rom_ds, |cpu1_rom_ds};
		din_next[0] = cpu1_rom_d;
	end else if (cpu2_rom_cs && !cpu2_rom_valid) begin
		next_port[0] = PORT_CPU2_ROM;
		addr_next[0][23:1] = cpu2_rom_addr[23:1];
		din_next[0] = {cpu2_rom_d, cpu2_rom_d};
		ds_next[0] = cpu2_rom_ds;
		{ oe_next[0], we_next[0] } = {cpu2_rom_rd, ~cpu2_rom_rd};
	end
end

// PORT1: bank 0,1,2
always @(*) begin
	next_port[1] = PORT_NONE;
	addr_next[1] = addr_latch[1];
	{ oe_next[1], we_next[1] } = 2'b10;
	din_next[1] = 0;
	ds_next[1] = 0;

	if (port2_req ^ port2_state) begin
		next_port[1] = PORT_REQ;
		addr_next[1] = port2_a;
		ds_next[1] <= port2_ds;
		din_next[1] <= port2_d;
		{ oe_next[1], we_next[1] } <= { ~port2_we, port2_we };
	end else if (sp_req ^ sp_req_state) begin
		next_port[1] = PORT_SP;
		addr_next[1] = { sp_addr[25:2], 1'b0 };
		ds_next[1] = 2'b11;
	end else if (samplea_req ^ samplea_req_state) begin
		next_port[1] = PORT_SAMPLEA;
		addr_next[1] = {samplea_addr[25:2], 1'b0};
		ds_next[1] = 2'b11;
	end else if (sampleb_req ^ sampleb_req_state) begin
		next_port[1] = PORT_SAMPLEB;
		addr_next[1] = {sampleb_addr[25:2], 1'b0};
		ds_next[1] = 2'b11;
	end else begin
		next_port[1] = PORT_NONE;
		addr_next[1] = addr_latch[1];
		{ oe_next[1], we_next[1] } = 2'b00;
	end
end

always @(posedge clk) begin

	// permanently latch ram data to reduce delays
	sd_din <= SDRAM_DQ;
	oe <= 0;
	{ SDRAM_DQMH, SDRAM_DQML } <= 2'b11;
	sd_cmd <= CMD_NOP;  // default: idle
	refresh_cnt <= refresh_cnt + 1'd1;

	if(init) begin
		cpu1_rom_valid <= 0;
		cpu2_rom_valid <= 0;
		sfix_valid <= 0;
		// initialization takes place at the end of the reset phase
		if(t == STATE_RAS0) begin

			if(reset == 15) begin
				sd_cmd <= CMD_PRECHARGE;
				SDRAM_A[10] <= 1'b1;      // precharge all banks
			end

			if(reset == 10 || reset == 8) begin
				sd_cmd <= CMD_AUTO_REFRESH;
			end

			if(reset == 2) begin
				sd_cmd <= CMD_LOAD_MODE;
				SDRAM_A <= MODE;
				SDRAM_BA <= 2'b00;
			end
		end
	end else begin
		if (!cpu1_rom_cs) cpu1_rom_valid <= 0;
		if (!cpu2_rom_cs) cpu2_rom_valid <= 0;
		if (!sfix_cs) sfix_valid <= 0;

		// RAS phase
		// bank 0,1
		if(t == STATE_RAS0) begin
			addr_latch[0] <= addr_next[0];
			port[0] <= next_port[0];
			ds[0] <= ds_next[0];
			{ oe_latch[0], we_latch[0] } <= { oe_next[0], we_next[0] };
			din_latch[0] <= din_next[0];

			if (next_port[0] != PORT_NONE) begin
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addr_next[0][22:10];
				SDRAM_BA <= addr_next[0][25:24];
			end
			case (next_port[0])
				PORT_REQ: port1_state <= port1_req;
				PORT_VRAM: begin vram_req_state <= vram_req; vram_sel_latch <= vram_sel; end
				PORT_LOROM: lo_rom_req_state <= lo_rom_req;
				default: ;
			endcase;
		end

		// bank 2,3
		if(t == STATE_RAS1) begin
			if (|refresh) refresh <= refresh - 1'd1;
			addr_latch[1] <= addr_next[1];
			{ oe_latch[1], we_latch[1] } <= { oe_next[1], we_next[1] };
			port[1] <= next_port[1];
			ds[1] <= ds_next[1];
			din_latch[1] <= din_next[1];

			if (next_port[1] != PORT_NONE) begin
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addr_next[1][22:10];
				// 6*8MiB -> Banks 0,1,2,2,0,1
				SDRAM_BA <= DUAL_BANK ?
					(addr_next[1][24:23] == 2'b11 ? 2'b10 : addr_next[1][24:23]) :
					addr_next[1][24:23];
			end
			case (next_port[1])
				PORT_REQ: port2_state <= port2_req;
				PORT_SP: sp_req_state <= sp_req;
				PORT_SAMPLEA: samplea_req_state <= samplea_req;
				PORT_SAMPLEB: sampleb_req_state <= sampleb_req;
				default:
					if (refresh_en && need_refresh && ~|refresh && !we_latch[0] && !oe_latch[0]) begin
						// refresh in RFRSH_CYCLES interval
						// suppress refresh if:
						// - a pendig access in the other bank
						// - refresh is not enabled
						// - 7 full cycles after the previous refresh
						refresh <= 3'd7;
						refresh_cnt <= refresh_cnt - RFRSH_CYCLES;
						sd_cmd <= CMD_AUTO_REFRESH;
					end
			endcase
		end

		// CAS phase
		if(t == STATE_CAS0 && (we_latch[0] || oe_latch[0])) begin
			sd_cmd <= we_latch[0]?CMD_WRITE:CMD_READ;
			{ SDRAM_DQMH, SDRAM_DQML } <= ~ds[0];
			// early ack for nDTACK/nWAIT
			if (port[0] == PORT_CPU1_ROM) cpu1_rom_valid <= 1;
			if (port[0] == PORT_CPU2_ROM) cpu2_rom_valid <= 1;
			if (we_latch[0]) begin
				sd_dout <= din_latch[0];
				oe <= 1;
				case(port[0])
					PORT_REQ: port1_ack <= port1_req;
					PORT_VRAM: begin
						vram_ack <= vram_req;
						vram_q2 <= din_latch[0];
						end
					default: ;
				endcase;
			end
			SDRAM_A <= { 3'b001, addr_latch[0][23], addr_latch[0][9:1] };  // auto precharge
			SDRAM_BA <= addr_latch[0][25:24];
		end

		//if(t == STATE_CAS1 && (we_latch[1] || oe_latch[1])) begin
		if((t == STATE_CAS1 && oe_latch[1]) || (t == STATE_CAS1+1 && we_latch[1])) begin
			sd_cmd <= we_latch[1]?CMD_WRITE:CMD_READ;
			{ SDRAM_DQMH, SDRAM_DQML } <= ~ds[1];
			if (we_latch[1]) begin
				sd_dout <= din_latch[1];
				oe <= 1;
				case(port[1])
					PORT_REQ: port2_ack <= port2_req;
					default: ;
				endcase;
			end
			if (DUAL_BANK) begin
				SDRAM_A <= { 3'b001, addr_latch[1][25:23] > 3'd2, addr_latch[1][9:1] };  // auto precharge
				SDRAM_BA <= addr_latch[1][24:23] == 2'b11 ? 2'b10 : addr_latch[1][24:23];
			end else begin
				SDRAM_A <= { 3'b001, addr_latch[1][25], addr_latch[1][9:1] };  // auto precharge
				SDRAM_BA <= addr_latch[1][24:23];
			end
		end

		if(t == STATE_DS0b && oe_latch[0]) { SDRAM_DQMH, SDRAM_DQML } <= 0;

		// Data returned
		if(t == STATE_READ0 && oe_latch[0]) begin
			case(port[0])
				PORT_REQ:  begin port1_q <= sd_din; port1_ack <= port1_req; end
				PORT_CPU1_ROM: begin cpu1_rom_q <= sd_din; end
				PORT_CPU2_ROM: begin cpu2_rom_q <= sd_din; end
				PORT_SFIX: begin sfix_q[15:0] <= sd_din; sfix_valid <= 1; end
				PORT_VRAM: if (vram_sel_latch) vram_q2 <= sd_din; else vram_q1[15:0] <= sd_din;
				PORT_LOROM: begin lo_rom_q <= sd_din; lo_rom_ack <= lo_rom_req; end
				default: ;
			endcase;
		end
		if(t == STATE_READ0b && oe_latch[0]) begin
			case(port[0])
				PORT_VRAM: begin if (!vram_sel_latch) vram_q1[31:16] <= sd_din; vram_ack <= vram_req; end
				default: ;
			endcase;
		end

		if(t == STATE_DS1b && oe_latch[1]) { SDRAM_DQMH, SDRAM_DQML } <= 0;

		if(t == STATE_READ1 && oe_latch[1]) begin
			case(port[1])
				PORT_REQ  :     port2_q[15:0] <= sd_din;
				PORT_SAMPLEA: samplea_q[15:0] <= sd_din;
				PORT_SAMPLEB: sampleb_q[15:0] <= sd_din;
				PORT_SP   :        sp_q[15:0] <= sd_din;
				default: ;
			endcase;
		end

		if(t == STATE_READ1b && oe_latch[1]) begin
			case(port[1])
				PORT_REQ  :   begin   port2_q[31:16] <= sd_din; port2_ack <= port2_req; end
				PORT_SAMPLEA: begin samplea_q[31:16] <= sd_din; samplea_ack <= samplea_req; end
				PORT_SAMPLEB: begin sampleb_q[31:16] <= sd_din; sampleb_ack <= sampleb_req; end
				PORT_SP   :   begin      sp_q[31:16] <= sd_din; sp_ack <= sp_req; end
				default: ;
			endcase;
		end
	end
end

endmodule
