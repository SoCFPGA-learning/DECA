//============================================================================
//  SNES top-level for DECA      ported from https://github.com/neptuno-fpga/SNES
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

module snes_deca
(
   input         CLOCK_50,   // Input clock 50 MHz

   output  [2:0] VGA_R,
   output  [2:0] VGA_G,
   output  [2:0] VGA_B,
   output        VGA_HS,
   output        VGA_VS,

   output        LED,

   output        AUDIO_L,
   output        AUDIO_R,

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
   output [20:0] SRAM_A,
   inout  [15:0] SRAM_D,
   output		  SRAM_nWE,
	output		  SRAM_nUB,
	output		  SRAM_nLB,
	output        SRAM_nOE,
   input         BUTTON,
   input         PS2_CLK,
   inout         PS2_DAT,
   output        JOY_CLK,
   output        JOY_LOAD,
   input         JOY_DATA,
   output        joyP7_o,
   output        LRCLK,
   output        SDIN,
   output        SCLK,
	// MicroSD Card 
	input         SPI_MISO,
	output        SPI_MOSI,
	output        SPI_CLK,
	output        SPI_CS,
	output		          		SD_SEL,
	output		          		SD_CMD_DIR,
	output		          		SD_D0_DIR,
	output		          		SD_D123_DIR,
   	//
	output        stm_rst_o
	
);

// MicroSD Card 
assign SD_SEL = 1'b0;   //0 = 3.3V at sdcard		
assign SD_CMD_DIR = 1'b1;  // MOSI FPGA output	
assign SD_D0_DIR = 1'b0;   // MISO FPGA input	
assign SD_D123_DIR = 1'b1; // CS FPGA output	
// 

wire MCLK;
assign SRAM_nWE = 1'b1;
assign SRAM_nUB = 1'b1;
assign SRAM_nLB = 1'b1;
assign SRAM_A = 21'b000000000000000000000;
assign SRAM_D[15:0] = 16'hZZZZ;
assign SRAM_nOE = 1'b1;
assign stm_rst_o = 1'b0;

assign LED  = ~ioctl_download & ~bk_ena;

wire [1:0] mouse_mode = status[6:5];
wire       multitap = status[17];
wire       bk_save = status[15];
wire       GUN_MODE = status[25];

wire [15:0] dipswitches;
wire [1:0] LHRom_type = dipswitches[1:0];
wire [1:0] scanlines = {1'b0, dipswitches[2]};
wire       joy_swap = dipswitches[3];
wire       video_region = dipswitches[4];
wire       BLEND = ~dipswitches[5];
wire [1:0] joy_map_1 = dipswitches[7:6];
wire [1:0] joy_map_2 = dipswitches[9:8];


////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys, clk_mem, clk_osd;

pll pll
(
	.inclk0(CLOCK_50),
	.c0(SDRAM_CLK),
	.c1(clk_mem),
	.c2(clk_sys),
	.c3(clk_osd),
	.locked(locked)
);

reg reset;
always @(posedge clk_sys) begin
	reset <= ~BUTTON | ~host_reset_n;
end

//////////////////   MiST I/O   ///////////////////

wire [31:0] status = 32'h00000000;
reg         ioctl_wrD;

/*
wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;  // YOvfl, XOvfl, dy8, dx8, 1, mbtn, rbtn, lbtn
wire        mouse_strobe;
*/
reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_buff_rd;
wire        img_mounted;
wire [31:0] img_size;

always @(posedge clk_sys) ioctl_wrD <= ioctl_wr;

////////////////////////////  SDRAM  ///////////////////////////////////
wire [23:0] ROM_ADDR;
wire [24:0] ioctl_addr_adj = ioctl_addr - ioctl_filesize[9:0]; // adjust for 512 byte SMC header
wire [23:1] rom_addr_rw = cart_download ? ioctl_addr_adj[23:1] : ROM_ADDR[23:1];
reg  [23:1] rom_addr_sd;
wire        ROM_CE_N;
wire        ROM_OE_N;
wire        ROM_WORD;
wire [15:0] ROM_Q = (ROM_WORD || ~ROM_ADDR[0]) ? rom_dout : { rom_dout[7:0], rom_dout[15:8] };
wire [15:0] rom_dout;
reg         rom_req;

wire [16:0] WRAM_ADDR;
reg  [16:0] wram_addr_sd;
wire        WRAM_CE_N;
wire        WRAM_OE_N;
wire        WRAM_RD_N;
wire        WRAM_WE_N;
wire  [7:0] WRAM_Q = WRAM_ADDR[0] ? wram_dout[15:8] : wram_dout[7:0];
wire  [7:0] WRAM_D;
reg   [7:0] wram_din;
wire [15:0] wram_dout;
wire        wram_rd = ~WRAM_CE_N & ~WRAM_RD_N;
reg         wram_rdD;
wire        wram_wr = ~WRAM_CE_N & ~WRAM_WE_N;
reg         wram_wrD;
wire        wram_req;

wire [19:0] BSRAM_ADDR;
reg  [19:0] bsram_sd_addr;
wire        BSRAM_CE_N;
wire        BSRAM_OE_N;
wire        BSRAM_WE_N;
wire        BSRAM_RD_N;
wire  [7:0] BSRAM_Q = BSRAM_ADDR[0] ? bsram_dout[15:8] : bsram_dout[7:0];
wire  [7:0] BSRAM_D;
reg   [7:0] bsram_din;
wire [15:0] bsram_dout;
wire        bsram_rd = ~BSRAM_CE_N & (~BSRAM_RD_N || rom_type[7:4] == 4'hC);
reg         bsram_rdD;
wire        bsram_wr = ~BSRAM_CE_N & ~BSRAM_WE_N;
reg         bsram_wrD;
wire        bsram_req;
reg         bsram_req_reg;

wire        VRAM_OE_N;

wire [15:0] VRAM1_ADDR;
reg  [14:0] vram1_addr_sd;
wire        VRAM1_WE_N;
wire  [7:0] VRAM1_D, VRAM1_Q;
reg   [7:0] vram1_din;
wire        vram1_req;
reg         vram1_req_reg;
reg         vram1_we_nD;

wire [15:0] VRAM2_ADDR;
reg  [14:0] vram2_addr_sd;
wire        VRAM2_WE_N;
wire  [7:0] VRAM2_D, VRAM2_Q;
reg   [7:0] vram2_din;
wire        vram2_req;
reg         vram2_req_reg;
reg         vram2_we_nD;

wire [15:0] ARAM_ADDR;
reg  [15:0] aram_addr_sd;
wire        ARAM_CE_N;
wire        ARAM_OE_N;
wire        ARAM_WE_N;
wire  [7:0] ARAM_Q;
wire  [7:0] ARAM_D;
reg   [7:0] aram_din;
wire [15:0] aram_dout;
wire        aram_rd = ~ARAM_CE_N & ~ARAM_OE_N;
reg         aram_rd_last;
wire        aram_wr = ~ARAM_CE_N & ~ARAM_WE_N;
reg         aram_wr_last;
wire        aram_req;
wire        aram_req_reg;

wire        DOT_CLK_CE;

always @(negedge clk_sys) begin

	reg ioctl_wr_last;

	ioctl_wr_last <= ioctl_wr;

	if ((~cart_download && ~ROM_CE_N /*&& ~ROM_OE_N */&& rom_addr_sd != rom_addr_rw) || ((ioctl_wr_last ^ ioctl_wr) & cart_download)) begin
		rom_req <= ~rom_req;
		rom_addr_sd <= rom_addr_rw;
	end

	if (reset) begin
//		aram_addr_sd <= 16'haaaa;
//		wram_addr_sd <= 17'h1aaaa;
//		vram1_addr_sd <= 15'h7fff;
//		vram2_addr_sd <= 15'h7fff;
	end else begin

		wram_rdD <= wram_rd;
		wram_wrD <= wram_wr;
		if ((wram_rd && WRAM_ADDR[16:1] != wram_addr_sd[16:1]) || (~wram_wrD & wram_wr) || (~wram_rdD & wram_rd)) begin
			wram_req <= ~wram_req;
			wram_addr_sd <= WRAM_ADDR;
			wram_din <= WRAM_D;
		end

		bsram_rdD <= bsram_rd;
		bsram_wrD <= bsram_wr;
		if ((bsram_rd && BSRAM_ADDR[19:1] != bsram_sd_addr[19:1]) || (~bsram_wrD & bsram_wr) || (~bsram_rdD & bsram_rd)) begin
			bsram_req <= ~bsram_req;
			bsram_sd_addr <= BSRAM_ADDR;
			bsram_din <= BSRAM_D;
		end

		aram_wr_last <= aram_wr;
		aram_rd_last <= aram_rd;
		if ((aram_rd && ARAM_ADDR[15:1] != aram_addr_sd[15:1]) || (aram_wr && ARAM_ADDR != aram_addr_sd) || (aram_rd & ~aram_rd_last) || (aram_wr & ~aram_wr_last)) begin
			aram_req <= ~aram_req;
			aram_addr_sd <= ARAM_ADDR;
			aram_din <= ARAM_D;
		end

		vram1_we_nD <= VRAM1_WE_N;
		if ((vram1_we_nD & ~VRAM1_WE_N) || (VRAM1_ADDR[14:0] != vram1_addr_sd && ~VRAM_OE_N)) begin
			vram1_addr_sd <= VRAM1_ADDR[14:0];
			vram1_din <= VRAM1_D;
			vram1_req <= ~vram1_req;
		end

		vram2_we_nD <= VRAM2_WE_N;
		if ((vram2_we_nD & ~VRAM2_WE_N) || (VRAM2_ADDR[14:0] != vram2_addr_sd && ~VRAM_OE_N)) begin
			vram2_addr_sd <= VRAM2_ADDR[14:0];
			vram2_din <= VRAM2_D;
			vram2_req <= ~vram2_req;
		end
	end

end

spram #(15)	vram1
(
	.clock(clk_sys),
	.address(VRAM1_ADDR[14:0]),
	.data(VRAM1_D),
	.wren(~VRAM1_WE_N),
	.q(VRAM1_Q)
);


spram #(15) vram2
(
	.clock(clk_sys),
	.address(VRAM2_ADDR[14:0]),
	.data(VRAM2_D),
	.wren(~VRAM2_WE_N),
	.q(VRAM2_Q)
);

spram #(16) aram
(
	.clock(clk_sys),
	.address(ARAM_ADDR),
	.data(ARAM_D),
	.wren(aram_wr),
	.q(ARAM_Q)
);

sdram sdram
(
	.*,
	.init_n(locked),
	.clk(clk_mem),
	.clkref(DOT_CLK_CE),

	.rom_addr(rom_addr_sd),
	.rom_din(ioctl_dout),
	.rom_dout(rom_dout),
	.rom_req(rom_req),
	.rom_req_ack(),
	.rom_we(cart_download),

	.wram_addr(wram_addr_sd),
	.wram_din(WRAM_D),
	.wram_dout(wram_dout),
	.wram_req(wram_req),
	.wram_req_ack(),
	.wram_we(wram_wrD),
	
	.bsram_addr(bsram_sd_addr),
//	.bsram_din(bsram_din),
	.bsram_din(BSRAM_D),
	.bsram_dout(bsram_dout),
	.bsram_req(bsram_req),
	.bsram_req_ack(),
//	.bsram_we(~BSRAM_WE_N),
	.bsram_we(bsram_wrD),

	.bsram_io_addr(BSRAM_IO_ADDR),
	.bsram_io_din(BSRAM_IO_D),
	.bsram_io_dout(BSRAM_IO_Q),
	.bsram_io_req(bsram_io_req),
	.bsram_io_req_ack(),
	.bsram_io_we(bk_load),

	.vram1_req(1'b0),
	.vram1_ack(),
	.vram1_addr(16'h0000),
	.vram1_din(8'h00),
	.vram1_dout(),
	.vram1_we(1'b0),

	.vram2_req(1'b0),
	.vram2_ack(),
	.vram2_addr(16'h0000),
	.vram2_din(8'h00),
	.vram2_dout(),
	.vram2_we(1'b0),

	.aram_addr(16'h0000),
	.aram_din(8'h00),
	.aram_dout(),
	.aram_req(1'b0),
	.aram_req_ack(),
	.aram_we(1'b0)
);

assign SDRAM_CKE = 1'b1;

//////////////////////////  ROM DETECT  /////////////////////////////////

wire cart_download = ioctl_download;

reg        PAL;
reg  [7:0] rom_type;
reg  [7:0] rom_type_header;
reg  [7:0] mapper_header;
reg  [7:0] company_header;
reg  [3:0] rom_size;
reg [23:0] rom_mask, ram_mask;

wire [8:0] hdr_prefix = LHRom_type == 2 ? { 8'h40, 1'b1 } : // ExHiROM
                        LHRom_type == 1 ? { 8'h00, 1'b1 } : // HiROM
						9'd0; // LoROM

always @(posedge clk_sys) begin
	reg [3:0] ram_size;

	if (cart_download) begin
		if(ioctl_wrD ^ ioctl_wr) begin
			if (ioctl_addr == 0) begin
				ram_size <= 4'h0;
				rom_type <= { 6'd0, LHRom_type };
			end

			if(ioctl_addr_adj == { hdr_prefix, 15'h7FD4 }) mapper_header <= ioctl_dout[15:8];
			if(ioctl_addr_adj == { hdr_prefix, 15'h7FD6 }) { rom_size, rom_type_header } <= ioctl_dout[11:0];
			if(ioctl_addr_adj == { hdr_prefix, 15'h7FD8 }) ram_size <= ioctl_dout[3:0];
			if(ioctl_addr_adj == { hdr_prefix, 15'h7FDA }) company_header <= ioctl_dout[7:0];

			rom_mask <= (24'd1024 << ((rom_size < 4'd7) ? 4'hC : rom_size)) - 1'd1;
			ram_mask <= ram_size ? (24'd1024 << ram_size) - 1'd1 : 24'd0;

		end
	end
	else begin
		PAL <= video_region;
		//DSP3
		if (mapper_header == 8'h30 && rom_type_header == 8'd5 && company_header == 8'hB2) rom_type[7:4] <= 4'hA;
		//DSP1
		else if (((mapper_header == 8'h20 || mapper_header == 8'h21) && rom_type_header == 8'd3) ||
		    (mapper_header == 8'h30 && rom_type_header == 8'd5) || 
		    (mapper_header == 8'h31 && (rom_type_header == 8'd3 || rom_type_header == 8'd5))) rom_type[7] <= 1'b1;
		//DSP2
		else if (mapper_header == 8'h20 && rom_type_header == 8'd5) rom_type[7:4] <= 4'h9;
		//DSP4
		else if (mapper_header == 8'h30 && rom_type_header == 8'd3) rom_type[7:4] <= 4'hB;
		//OBC1
		else if (mapper_header == 8'h30 && rom_type_header == 8'h25) rom_type[7:4] <= 4'hC;
		//SDD1
		else if (mapper_header == 8'h32 && (rom_type_header == 8'h43 || rom_type_header == 8'h45)) rom_type[7:4] <= 4'h5;
		//ST0XX
		else if (mapper_header == 8'h30 && rom_type_header == 8'hf6) begin
			rom_type[7:3] <= { 4'h8, 1'b1 };
			if (rom_size < 4'd10) rom_type[5] <= 1'b1; // Hayazashi Nidan Morita Shougi
		end
		//GSU
		else if (mapper_header == 8'h20 &&
		    (rom_type_header == 8'h13 || rom_type_header == 8'h14 || rom_type_header == 8'h15 || rom_type_header == 8'h1a))
		begin
			rom_type[7:4] <= 4'h7;
			ram_mask <= (24'd1024 << 4'd6) - 1'd1;
		end
		//SA1
		else if (mapper_header == 8'h23 && (rom_type_header == 8'h32 || rom_type_header == 8'h34 || rom_type_header == 8'h35)) rom_type[7:4] <= 4'h6;
	end
end

////////////////////////////  SYSTEM  ///////////////////////////////////

//main #(.USE_DSPn(1'b1), .USE_CX4(1'b0), .USE_SDD1(1'b1), .USE_SA1(1'b1), .USE_GSU(1'b1), .USE_DLH(1'b1), .USE_SPC7110(1'b1)) main
main #(.USE_DSPn(1'b0), .USE_CX4(1'b0), .USE_SDD1(1'b1), .USE_SA1(1'b1), .USE_GSU(1'b1), .USE_DLH(1'b1), .USE_SPC7110(1'b1)) main
(
	.RESET_N(~reset),

	.MCLK(clk_sys), // 21.47727 / 21.28137
	.ACLK(clk_sys),
	.HALT(bk_state == 1'b1),

	.GSU_ACTIVE(),
	.GSU_TURBO(1'b0),

	.ROM_TYPE(rom_type),
	.ROM_MASK(rom_mask),
	.RAM_MASK(ram_mask),
	.PAL(PAL),
	.BLEND(BLEND),

	.ROM_ADDR(ROM_ADDR),
	.ROM_Q(ROM_Q),
	.ROM_CE_N(ROM_CE_N),
	.ROM_OE_N(ROM_OE_N),
	.ROM_WORD(ROM_WORD),

	.BSRAM_ADDR(BSRAM_ADDR),
	.BSRAM_D(BSRAM_D),
	.BSRAM_Q(BSRAM_Q),
	.BSRAM_CE_N(BSRAM_CE_N),
	.BSRAM_OE_N(BSRAM_OE_N),
	.BSRAM_WE_N(BSRAM_WE_N),
	.BSRAM_RD_N(BSRAM_RD_N),

	.WRAM_ADDR(WRAM_ADDR),
	.WRAM_D(WRAM_D),
	.WRAM_Q(WRAM_Q),
	.WRAM_CE_N(WRAM_CE_N),
	.WRAM_OE_N(WRAM_OE_N),
	.WRAM_WE_N(WRAM_WE_N),
	.WRAM_RD_N(WRAM_RD_N),

	.VRAM_OE_N(VRAM_OE_N),

	.VRAM1_ADDR(VRAM1_ADDR),
	.VRAM1_DI(VRAM1_Q),
	.VRAM1_DO(VRAM1_D),
	.VRAM1_WE_N(VRAM1_WE_N),

	.VRAM2_ADDR(VRAM2_ADDR),
	.VRAM2_DI(VRAM2_Q),
	.VRAM2_DO(VRAM2_D),
	.VRAM2_WE_N(VRAM2_WE_N),

	.ARAM_ADDR(ARAM_ADDR),
	.ARAM_D(ARAM_D),
	.ARAM_Q(ARAM_Q),
	.ARAM_CE_N(ARAM_CE_N),
	.ARAM_OE_N(ARAM_OE_N),
	.ARAM_WE_N(ARAM_WE_N),

	.R(R),
	.G(G),
	.B(B),

	.FIELD(),
	.INTERLACE(),
	.HIGH_RES(),
	.DOTCLK(DOTCLK),
	.DOT_CLK_CE(DOT_CLK_CE),

	.HBLANKn(HBLANKn),
	.VBLANKn(VBLANKn),
	.HSYNC(HSYNC),
	.VSYNC(VSYNC),

	.JOY1_DI(JOY1_DO),
	.JOY2_DI(GUN_MODE ? LG_DO : JOY2_DO),
	.JOY_STRB(JOY_STRB),
	.JOY1_CLK(JOY1_CLK),
	.JOY2_CLK(JOY2_CLK),
	.JOY1_P6(JOY1_P6),
	.JOY2_P6(JOY2_P6),
	.JOY2_P6_in(JOY2_P6_DI),

	.GG_EN(1'b0),
	.GG_CODE(),
	.GG_RESET(),
	.GG_AVAILABLE(1'b0),

	.TURBO(1'b0),
	.TURBO_ALLOW(),

	.AUDIO_L(audioL),
	.AUDIO_R(audioR)
);

//////////////////   VIDEO   //////////////////
wire [7:0] R,G,B;
wire       HSYNC,VSYNC;
wire       HBLANKn,VBLANKn;
wire       BLANK = ~(HBLANKn & VBLANKn);


mist_video #(.SD_HCNT_WIDTH(10), .COLOR_DEPTH(6), .OSD_AUTO_CE(1'b0)) mist_video
(
	.clk_sys(clk_sys),
	.scanlines(scanlines),
	.scandoubler_disable(~scandoubler),

	.rotate(2'b00),
	.ce_divider(1'b0),
	.HSync(~HSYNC),
	.VSync(~VSYNC),
	.R(BLANK ? 6'd0 : R[7:2]),
	.G(BLANK ? 6'd0 : G[7:2]),
	.B(BLANK ? 6'd0 : B[7:2]),
	.VGA_HS(mist_hsync),
	.VGA_VS(mist_vsync),
	.VGA_R(mist_red),
	.VGA_G(mist_green),
	.VGA_B(mist_blue)
);

//////////////////   AUDIO   //////////////////
wire [15:0] audioL, audioR;

hybrid_pwm_sd dacl
(
	.clk(clk_sys),
	.n_reset(~reset),
	.din({~audioL[15], audioL[14:0]}),
	.dout(AUDIO_L)
);

hybrid_pwm_sd dacr
(
	.clk(clk_sys),
	.n_reset(~reset),
	.din({~audioR[15], audioR[14:0]}),
	.dout(AUDIO_R)
);

audio_top audio_top  
(
	.clk_50MHz (CLOCK_50),
	.dac_MCLK  (MCLK),
	.dac_LRCK  (LRCLK),
	.dac_SCLK  (SCLK),
	.dac_SDIN  (SDIN),
	.L_data    (audioL),
	.R_data    (audioR)
); 

////////////////////////////  I/O PORTS  ////////////////////////////////
wire joy1up;
wire joy1down;
wire joy1left;
wire joy1right;
wire joy1fire1;
wire joy1fire2;
wire joy1start;
wire joy2up;
wire joy2down;
wire joy2left;
wire joy2right;
wire joy2fire1;
wire joy2fire2;
wire joy2start;

reg [11:0] joy1_o;
reg [11:0] joy2_o;

joydecoder joysticks_neptuno
(
	.clk(CLOCK_50),
	.joy_data(JOY_DATA),
	.joy_clk(JOY_CLK),
	.joy_load_n(JOY_LOAD),
	.joy1up(joy1up),
	.joy1down(joy1down),
	.joy1left(joy1left),
	.joy1right(joy1right),
	.joy1fire1(joy1fire1),
	.joy1fire2(joy1fire2),
	.joy2up(joy2up),
	.joy2down(joy2down),
	.joy2left(joy2left),
	.joy2right(joy2right),
	.joy2fire1(joy2fire1),
	.joy2fire2(joy2fire2)
);

	
sega_joystick joy
(
 .joy1_up_i		(joy1up),
 .joy1_down_i	(joy1down),
 .joy1_left_i	(joy1left),
 .joy1_right_i	(joy1right),
 .joy1_p6_i		(joy1fire1),
 .joy1_p9_i		(joy1fire2),
 .joy2_up_i		(joy2up),
 .joy2_down_i	(joy2down),
 .joy2_left_i	(joy2left),
 .joy2_right_i	(joy2right),
 .joy2_p6_i		(joy2fire1),
 .joy2_p9_i		(joy2fire2),
 .vga_hsync_n_s(HSYNC),
 .joyX_p7_o		(joyP7_o),
 .joy1_o			(joy1_o),   // Mode X Y Z Start A C B Right Left Down Up
 .joy2_o			(joy2_o)    //  11 10 9 8   7   6 5 4   3    2     1   0
);


// Joystick button mapping
// A: A=X B=B C=A X=L Y=Y Z=R
// B: A=L B=Y C=X X=R Y=B Z=A
// C: A=R B=B C=A X=L Y=Y Z=X
// D: A=Y B=L C=R X=B Y=A Z=X
wire p1r, p1l, p1y, p1x, p1b, p1a;
wire p2r, p2l, p2y, p2x, p2b, p2a;
assign p1r = (joy_map_1 == 2'b01) ? ~joy1_o[10] : (joy_map_1 == 2'b10) ? ~joy1_o[6] : (joy_map_1 == 2'b11) ? ~joy1_o[5] : ~joy1_o[8];
assign p1l = (joy_map_1 == 2'b01) ? ~joy1_o[6] : (joy_map_1 == 2'b10) ? ~joy1_o[10] : (joy_map_1 == 2'b11) ? ~joy1_o[4] : ~joy1_o[10];
assign p1y = (joy_map_1 == 2'b01) ? ~joy1_o[4] : (joy_map_1 == 2'b10) ? ~joy1_o[9] : (joy_map_1 == 2'b11) ? ~joy1_o[6] : ~joy1_o[9];
assign p1x = (joy_map_1 == 2'b01) ? ~joy1_o[5] : (joy_map_1 == 2'b10) ? ~joy1_o[8] : (joy_map_1 == 2'b11) ? ~joy1_o[8] : ~joy1_o[6];
assign p1b = (joy_map_1 == 2'b01) ? ~joy1_o[9] : (joy_map_1 == 2'b10) ? ~joy1_o[4] : (joy_map_1 == 2'b11) ? ~joy1_o[10] : ~joy1_o[4];
assign p1a = (joy_map_1 == 2'b01) ? ~joy1_o[8] : (joy_map_1 == 2'b10) ? ~joy1_o[5] : (joy_map_1 == 2'b11) ? ~joy1_o[9] : ~joy1_o[5];

assign p2r = (joy_map_2 == 2'b01) ? ~joy2_o[10] : (joy_map_2 == 2'b10) ? ~joy2_o[6] : (joy_map_2 == 2'b11) ? ~joy2_o[5] : ~joy2_o[8];
assign p2l = (joy_map_2 == 2'b01) ? ~joy2_o[6] : (joy_map_2 == 2'b10) ? ~joy2_o[10] : (joy_map_2 == 2'b11) ? ~joy2_o[4] : ~joy2_o[10];
assign p2y = (joy_map_2 == 2'b01) ? ~joy2_o[4] : (joy_map_2 == 2'b10) ? ~joy2_o[9] : (joy_map_2 == 2'b11) ? ~joy2_o[6] : ~joy2_o[9];
assign p2x = (joy_map_2 == 2'b01) ? ~joy2_o[5] : (joy_map_2 == 2'b10) ? ~joy2_o[8] : (joy_map_2 == 2'b11) ? ~joy2_o[8] : ~joy2_o[6];
assign p2b = (joy_map_2 == 2'b01) ? ~joy2_o[9] : (joy_map_2 == 2'b10) ? ~joy2_o[4] : (joy_map_2 == 2'b11) ? ~joy2_o[10] : ~joy2_o[4];
assign p2a = (joy_map_2 == 2'b01) ? ~joy2_o[8] : (joy_map_2 == 2'b10) ? ~joy2_o[5] : (joy_map_2 == 2'b11) ? ~joy2_o[9] : ~joy2_o[5];

// Start Select R L Y X B A Up Down Left Right
wire [11:0] joy0 = {~joy1_o[7] | scanSW[10], ~joy1_o[11] | scanSW[11], p1r | scanSW[9], p1l | scanSW[8], p1y | scanSW[7], p1x | scanSW[6], p1b | scanSW[5], p1a | scanSW[4], ~joy1_o[0] | scanSW[0], ~joy1_o[1] | scanSW[1], ~joy1_o[2] | scanSW[2], ~joy1_o[3] | scanSW[3]};
wire [11:0] joy1 = {~joy2_o[7] | scanSW[23], ~joy2_o[11] | scanSW[24], p2r | scanSW[22], p2l | scanSW[21], p2y | scanSW[20], p2x | scanSW[19], p2b | scanSW[18], p2a | scanSW[17], ~joy2_o[0] | scanSW[12], ~joy2_o[1] | scanSW[13] | scanSW[14], ~joy2_o[2] | scanSW[15], ~joy2_o[3] | scanSW[16]};

reg [11:0] joy2 = 12'h0;
reg [11:0] joy3 = 12'h0;
reg [11:0] joy4 = 12'h0;

wire       JOY_STRB;

wire [1:0] JOY1_DO;
wire       JOY1_CLK;
wire       JOY1_P6;
ioport port1
(
	.CLK(clk_sys),

	.PORT_LATCH(JOY_STRB),
	.PORT_CLK(JOY1_CLK),
	.PORT_P6(JOY1_P6),
	.PORT_DO(JOY1_DO),

	.JOYSTICK1(joy_swap ? joy1 : joy0),

	.MOUSE(ps2_mouse),
	.MOUSE_EN(mouse_mode[0])
);

wire [1:0] JOY2_DO;
wire       JOY2_CLK;
wire       JOY2_P6;
//wire       JOY2_P6_DI = (LG_P6_out | !GUN_MODE);

ioport port2
(
	.CLK(clk_sys),

	.MULTITAP(multitap),

	.PORT_LATCH(JOY_STRB),
	.PORT_CLK(JOY2_CLK),
	.PORT_P6(JOY2_P6),
	.PORT_DO(JOY2_DO),

	.JOYSTICK1(joy_swap ? joy0 : joy1),
	.JOYSTICK2(joy2),
	.JOYSTICK3(joy3),
	.JOYSTICK4(joy4),

	.MOUSE(ps2_mouse),
	.MOUSE_EN(mouse_mode[1])
);
/*
wire       LG_P6_out;
wire [1:0] LG_DO;
wire [2:0] LG_TARGET;
wire       LG_T = joy0[6] | joy1[6]; // always from joysticks
wire       DOTCLK;

lightgun lightgun
(
	.CLK(clk_sys),
	.RESET(reset),

	.MOUSE(ps2_mouse),
	.MOUSE_XY(1'b1),

	.JOY_X(),
	.JOY_Y(),

	.F(ps2_mouse[0]),
	.C(ps2_mouse[1]),
	.T(LG_T), // always from joysticks
	.P(ps2_mouse[2] | joy0[7] | joy1), // always from joysticks and mouse

	.HDE(HBLANKn),
	.VDE(VBLANKn),
	.CLKPIX(DOTCLK),

	.TARGET(LG_TARGET),
	.SIZE(1'b0),

	.PORT_LATCH(JOY_STRB),
	.PORT_CLK(JOY2_CLK),
	.PORT_P6(LG_P6_out),
	.PORT_DO(LG_DO)
);
*/
//////////////////////////// BACKUP RAM /////////////////////
reg  [19:1] BSRAM_IO_ADDR;
wire [15:0] BSRAM_IO_D;
wire [15:0] BSRAM_IO_Q;
reg  [15:0] bsram_io_q_save;
reg         bsram_io_req;
reg         bk_ena, bk_load;
reg         bk_state;
reg  [11:0] sav_size;

assign      sd_buff_din = sd_buff_addr[0] ? bsram_io_q_save[15:8] : bsram_io_q_save[7:0];

always @(posedge clk_sys) begin

	reg img_mountedD;
	reg ioctl_downloadD;
	reg bk_loadD, bk_saveD;
	reg sd_ackD;

	if (reset) begin
		bk_ena <= 0;
		bk_state <= 0;
		bk_load <= 0;
	end else begin
		img_mountedD <= img_mounted;
		if (~img_mountedD & img_mounted) begin
			if (|img_size) begin
				bk_ena <= 1;
				bk_load <= 1;
				sav_size <= img_size[20:9];
			end else begin
				bk_ena <= 0;
			end
		end

		ioctl_downloadD <= ioctl_download;
		if (~ioctl_downloadD & ioctl_download) bk_ena <= 0;

		bk_loadD <= bk_load;
		bk_saveD <= bk_save;
		sd_ackD  <= sd_ack;

		if (~sd_ackD & sd_ack) { sd_rd, sd_wr } <= 2'b00;

		case (bk_state)
		0:	if (bk_ena && ((~bk_loadD & bk_load) || (~bk_saveD & bk_save))) begin
				bk_state <= 1;
				sd_lba <= 0;
				sd_rd <= bk_load;
				sd_wr <= ~bk_load;
				if (bk_save) begin
					BSRAM_IO_ADDR <= 0;
					bsram_io_req <= ~bsram_io_req;
				end else
					BSRAM_IO_ADDR <= 19'h7ffff;
			end
		1:	if (sd_ackD & ~sd_ack) begin
				if (sd_lba[11:0] == sav_size) begin
					bk_load <= 0;
					bk_state <= 0;
				end else begin
					sd_lba <= sd_lba + 1'd1;
					sd_rd  <= bk_load;
					sd_wr  <= ~bk_load;
				end
			end
		endcase

		if (sd_buff_wr) begin
			if (sd_buff_addr[0]) begin
				BSRAM_IO_D[15:8] <= sd_buff_dout;
				bsram_io_req <= ~bsram_io_req;
				BSRAM_IO_ADDR <= BSRAM_IO_ADDR + 1'd1;
			end else
				BSRAM_IO_D[7:0] <= sd_buff_dout;
		end

		if (~sd_buff_addr[0]) bsram_io_q_save <= BSRAM_IO_Q;

		if (sd_buff_rd & sd_buff_addr[0]) begin
			bsram_io_req <= ~bsram_io_req;
			BSRAM_IO_ADDR <= BSRAM_IO_ADDR + 1'd1;
		end
	end
end

wire [25:0]scanSW;
wire [5:0] mist_blue;
wire [5:0] mist_green;
wire [5:0] mist_red;
wire mist_vsync;
wire mist_hsync;

wire [7:0] vga_blue;
assign vga_blue = {mist_blue[5:0], 2'b00};
wire [7:0] vga_green;
assign vga_green = {mist_green[5:0], 2'b00};
wire [7:0] vga_red;
assign vga_red = {mist_red[5:0], 2'b00};

wire [7:0] vga_osd_r;
wire [7:0] vga_osd_g;
wire [7:0] vga_osd_b;

wire scandoubler = scanSW[25] ^ 1'b1;
assign VGA_HS = scandoubler ? mist_hsync : !(mist_hsync ^ mist_vsync);
assign VGA_VS = scandoubler ? mist_vsync : 1'b1; 
assign VGA_R = vga_osd_r[7:5];
assign VGA_G = vga_osd_g[7:5];
assign VGA_B = vga_osd_b[7:5];

assign ps2k_dat_in = PS2_DAT;
assign PS2_DAT = (ps2k_dat_out == 1'b0) ? 1'b0 : 1'bz;
assign ps2k_clk_in = PS2_CLK;

assign ps2k_clk_out = 1'b1;
assign ps2k_dat_out = 1'b1;


wire spi_miso_d;
assign spi_miso_d = (SPI_CS == 1'b0)? SPI_MISO : 1'b0; 

reg rom_loaded = 0;
wire [31:0] bootdata;
wire bootdata_req;
reg bootdata_ack;
reg [23:0] ioctl_addr = 24'hFFFFFE;
reg [15:0] ioctl_dout = 16'h0000;
wire ioctl_download;
reg ioctl_wr = 1'b0;
reg [2:0] bootdata_pos = 3'b000;
wire [31:0] ioctl_filesize;
assign img_mounted = rom_loaded & host_reset_n;

always @(posedge clk_sys) begin
	if (host_reset_loader == 1'b1) begin
		bootdata_ack <= 1'b0;
		bootdata_pos <= 2'b00;
		ioctl_addr <= 24'hFFFFFE;
		ioctl_dout <= 16'h0000;
		ioctl_wr <= 1'b0;
		rom_loaded <= 1'b0;
	end

	if (bootdata_req  & (bootdata_ack == 1'b0)) begin
		case (bootdata_pos)
			3'b000: begin
				ioctl_addr <= ioctl_addr + 2'b10;
				ioctl_dout <= {bootdata[23:16], bootdata[31:24]};
			end
			3'b001: begin
				ioctl_dout <= {bootdata[23:16], bootdata[31:24]};
			end
			3'b010: begin
				ioctl_dout <= {bootdata[23:16], bootdata[31:24]};
			end
			3'b011: begin
				ioctl_dout <= {bootdata[23:16], bootdata[31:24]};
			end
			3'b100: begin
				ioctl_addr <= ioctl_addr + 2'b10;
				ioctl_dout <= {bootdata[7:0], bootdata[15:8]};
			end
			3'b101: begin
				ioctl_dout <= {bootdata[7:0], bootdata[15:8]};
			end
			3'b110: begin
				ioctl_dout <= {bootdata[7:0], bootdata[15:8]};
			end
			3'b111: begin
				ioctl_dout <= {bootdata[7:0], bootdata[15:8]};
				bootdata_ack <= 1'b1;
			end
		endcase

		ioctl_wr <= 1'b1;
		bootdata_pos <= bootdata_pos + 1'b1;
		rom_loaded <= 1'b1;
	end
	else begin 
		bootdata_ack <= 1'b0;
		ioctl_wr <= 1'b0;
	end
end

wire host_divert_keyboard;
CtrlModule control (
	.clk(clk_osd), 
	.reset_n(1'b1), 
	.vga_hsync(mist_hsync), 
	.vga_vsync(mist_vsync), 
	.osd_window(osd_window), 
	.osd_pixel(osd_pixel), 
	.ps2k_clk_in(ps2k_clk_in), 
	.ps2k_dat_in(ps2k_dat_in),
	.spi_miso(spi_miso_d),
	.spi_mosi(SPI_MOSI), 
	.spi_clk(SPI_CLK), 
	.spi_cs(SPI_CS), 
	.dipswitches(dipswitches), 
	.size(ioctl_filesize), 
	.host_divert_sdcard(host_divert_sdcard), 
	.host_divert_keyboard(host_divert_keyboard), 
	.host_reset_n(host_reset_n), 
	.host_reset_loader(host_reset_loader),
	.host_bootdata(bootdata), 
	.host_bootdata_req(bootdata_req), 
	.host_bootdata_ack(bootdata_ack),
	.host_download(ioctl_download)
);

OSD_Overlay osd (
	.clk(clk_osd),
	.red_in(vga_red),
	.green_in(vga_green),
	.blue_in(vga_blue),
	.window_in(1'b1),
	.hsync_in(mist_hsync),
	.osd_window_in(osd_window),
	.osd_pixel_in(osd_pixel),
	.red_out(vga_osd_r),
	.green_out(vga_osd_g),
	.blue_out(vga_osd_b),
	.window_out(),
	.scanline_ena(1'b0)
);

  keyboard keyb (
	.CLOCK(clk_sys),
	.PS2_CLK(PS2_CLK),
	.PS2_DATA(PS2_DAT),
	.resetKey(resetKey),
	.MRESET(master_reset),
	.scanSW(scanSW)
);
	
endmodule
